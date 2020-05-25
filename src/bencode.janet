#
# Provides functions for decoding data in the bencode format.
#

# Special ASCII characters use during parsing
(def MINUS 45)
(def INT-FLAG 105)
(def LENGTH-SEPARATOR 58)
(def END-FLAG 101)
(def LIST-FLAG 108)
(def DICTIONARY-FLAG 100)

(defn reader
  "Returns a \"reader\" for the buffer.

  A reader is a table with two keys...
    :index  a pointer to the next byte to be read
    :buffer the buffer being read."
  [buffer &opt index-in]
  (let [index (if-not (nil? index-in) index-in 0)]
    @{:index index :buffer buffer}))

(defn parse-error
  "Throws an error with the provided message for the given reader, the error
  will include the index of the reader."
  [message reader-in]
  (error (string message " at index " (get reader-in :index))))

(defn end?
  "Returns true if the index points to the end of the buffer"
  [reader-in]
  (if (= (get reader-in :index) (length (get reader-in :buffer)))
    true false))

(defn peek-byte
  "Returns the byte at the reader's current index"
  [reader-in]
  (let [byte (get (get reader-in :buffer) (get reader-in :index))]
    byte))

(defn read-byte
  "Returns the byte at the reader's current index and advances the index"
  [reader-in]
  (if (end? reader-in)
    (error "Read past the end of the buffer")
    (let [input (peek-byte reader-in)]
      (put reader-in :index (+ (get reader-in :index) 1))
      input)))

(defn match-byte
  "If the reader's next byte  matches the provided byte, advances the reader"
  [reader-in byte]
  (cond
    (= byte (peek-byte reader-in)) (read-byte reader-in)
    (end? reader-in) false
    false))

(defn digit-byte?
  "Returns true if the provided byte represents a digit"
  [byte]
  (if (and (< 47 byte) (> 58 byte)) true false))

(defn read-integer-bytes
  "Reads the next integer from the buffer

  The integer may include a minus indicating sign, we simply keep reading bytes
  as long as they represent a digit."
  [reader-in]
  (let [buffer-out (buffer/new 0)]

    # check to see if the number is signed
    (if (= MINUS (peek-byte reader-in))
      (buffer/push-byte buffer-out (read-byte reader-in)))

    # make sure we have at least one digit
    (if (not (digit-byte? (peek-byte reader-in)))
      (parse-error "No digits for integer" reader-in))

    # read all of the digits
    (while (digit-byte? (peek-byte reader-in))
      (buffer/push-byte buffer-out (read-byte reader-in)))
    (scan-number buffer-out)))

(defn read-integer
  "Reads a bencoded integer from the reader"
  [reader-in]
  (if-not (match-byte reader-in INT-FLAG)
    (parse-error "No integer found" reader-in))
  (let [int-in (try (read-integer-bytes reader-in)
                    ([error] (parse-error (string "Couldn't read integer: " error)
                                          reader-in)))]
    (if-not (match-byte reader-in END-FLAG)
      (parse-error "Unterminated integer" reader-in))
    int-in))

(defn read-string
  "Reads a bencoded binary string from the reader"
  [reader-in]
  (if-not (digit-byte? (peek-byte reader-in))
    (parse-error "No length found for string" reader-in))

  (let [length (read-integer-bytes reader-in)
        buffer-out (buffer/new 0)]

    (if (<= length 0)
      (parse-error "String length must be greater than 0" reader-in))

    (if-not (match-byte reader-in LENGTH-SEPARATOR)
      (parse-error "No separator \":\" after string length" reader-in))

    (for count 0 length
      (buffer/push-byte buffer-out (read-byte reader-in)))
    buffer-out))

(defn read-list
  "Reads a list, using the read-bencode-fn to parse items, from the reader"
  [read-bencode-fn reader-in]
  (if-not (match-byte reader-in LIST-FLAG)
    (parse-error "No list found" reader-in))
  (let [list-out (array/new 0)]
    (while (not (or (= END-FLAG (peek-byte reader-in))
                    (end? reader-in)))
      (let [token (read-bencode-fn reader-in)]
        (array/push list-out token)))
    (if-not (match-byte reader-in END-FLAG)
      (parse-error "Unterminated list" reader-in))
    list-out))

(defn read-dictionary
  "Reads a dictionary, using the read-bencode-fn to parse items, from the reader"
  [read-bencode-fn keyword-dicts reader-in]
  (if-not (match-byte reader-in DICTIONARY-FLAG)
    (parse-error "No dictionary found" reader-in))
  (let [dict-out @{}]
    (while (not (or (= END-FLAG (peek-byte reader-in))
                    (end? reader-in)))
      (let [key-in (try (read-string reader-in)
                        ([error] (parse-error (string "Couldn't read key: " error)
                                              reader-in)))
            val-in (try (read-bencode-fn reader-in)
                        ([error] (parse-error (string "Couldn't read value: " error)
                                              reader-in)))]
        (put dict-out
             (if keyword (keyword key-in) key-in)
             val-in)))
    (if-not (match-byte reader-in END-FLAG)
      (parse-error "Unterminated dictionary" reader-in))
    dict-out))

(defn read
  "Reads the next bencoded value from the reader"
  [reader-in &opt keyword-dicts]
  (cond
    (= INT-FLAG (peek-byte reader-in))
    (read-integer reader-in)

    # strings begin with an integer indicating their length
    (digit-byte? (peek-byte reader-in))
    (read-string reader-in)

    (= LIST-FLAG (peek-byte reader-in))
    (read-list read reader-in)

    (= DICTIONARY-FLAG (peek-byte reader-in))
    (read-dictionary read keyword-dicts reader-in)

    (parse-error "Unrecognized token" reader-in)))

# (def x (read (reader "d3:agei45e6:familyl6:joanna5:emily4:finne7:addressd3:zip5:01027ee")))

