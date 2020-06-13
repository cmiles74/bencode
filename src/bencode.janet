#
# Provides functions for decoding data in the bencode format.
#

# Special ASCII characters use during parsing
(def- MINUS 45)
(def- INT-FLAG 105)
(def- LENGTH-SEPARATOR 58)
(def- END-FLAG 101)
(def- LIST-FLAG 108)
(def- DICTIONARY-FLAG 100)

(defn- parse-error
  "Throws an error with the provided message for the given reader, the error
  will include the index of the reader."
  [message &opt reader-in]
  (if reader-in
    (error (string message " at index " (reader-in :index)))
    (error (string message))))

(defn- write-error
  "Throws an error with the provided message for the given data object"
  [message &opt data]
  (if data
    (error (string message " when writing data of type " (type data)))
    (error (string message))))

(defn- peek-byte
  "Returns the byte at the reader's current index"
  [reader-in]
  (let [byte (get (reader-in :buffer) (reader-in :index))]
    byte))

(defn- end?
  "Returns true if the index points to the end of the buffer"
  [reader-in]
  (if (nil? (peek-byte reader-in))
    true false))

(defn- read-byte
  "Returns the byte at the reader's current index and advances the index"
  [reader-in]
  (if (end? reader-in)
    (error "Read past the end of the buffer")
    (let [input (peek-byte reader-in)]
      (put reader-in :index (+ (reader-in :index) 1))
      input)))

(defn- match-byte
  "If the reader's next byte  matches the provided byte, advances the reader"
  [reader-in byte]
  (cond
    (= byte (peek-byte reader-in)) (read-byte reader-in)
    (end? reader-in) false
    false))

(defn- digit-byte?
  "Returns true if the provided byte represents a digit"
  [byte]
  (if (and (< 47 byte) (> 58 byte)) true false))

(defn- read-integer-bytes
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

(defn- read-integer
  "Reads a bencoded integer from the reader"
  [reader-in]
  (if-not (match-byte reader-in INT-FLAG)
    (parse-error "No integer found" reader-in))
  (let [int-in (try (read-integer-bytes reader-in)
                    ([error] (parse-error
                              (string "Couldn't read integer: " error))))]
    (if-not (match-byte reader-in END-FLAG)
      (parse-error "Unterminated integer" reader-in))
    int-in))

(defn- read-string
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

(defn- read-list
  "Reads a list, using the read-bencode-fn to parse nested structures, from
  the reader"
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
    (apply tuple list-out)))

(defn- read-dictionary
  "Reads a dictionary, using the read-bencode-fn to parse nested structures,
  from the reader"
  [read-bencode-fn keyword-dicts reader-in]
  (if-not (match-byte reader-in DICTIONARY-FLAG)
    (parse-error "No dictionary found" reader-in))
  (let [dict-out @{}]
    (while (not (or (= END-FLAG (peek-byte reader-in))
                    (end? reader-in)))
      (let [key-in (try (read-string reader-in)
                        ([error] (parse-error
                                  (string "Couldn't read key: " error))))
            val-in (try (read-bencode-fn reader-in)
                        ([error] (parse-error
                                  (string "Couldn't read value: " error))))]
        (put dict-out
             (if keyword-dicts (keyword key-in) key-in)
             val-in)))
    (if-not (match-byte reader-in END-FLAG)
      (parse-error "Unterminated dictionary" reader-in))
    (table/to-struct dict-out)))

(defn- read-bencode
  "Reads the next bencoded value from the reader, returns null if there is no
  data left to read. If the keyword-dicts value is true then the keys of
  dictionaries will be turned into keywords"
  [keyword-dicts reader-in]
  (let [read-fn (partial read-bencode keyword-dicts)]
    (cond
      (end? reader-in)
      nil

      (= INT-FLAG (peek-byte reader-in))
      (read-integer reader-in)

      # strings begin with an integer indicating their length
      (digit-byte? (peek-byte reader-in))
      (read-string reader-in)

      (= LIST-FLAG (peek-byte reader-in))
      (read-list read-fn reader-in)

      (= DICTIONARY-FLAG (peek-byte reader-in))
      (read-dictionary read-fn keyword-dicts reader-in)

      (parse-error "Unrecognized token" reader-in))))

(defn reader
  "Returns a \"reader\" for the buffer.

  A reader is a table with two keys...
    :index  a pointer to the next byte to be read
    :buffer the buffer being read."
  [buffer &opt index-in]
  (let [index (if-not (nil? index-in) index-in 0)]
    @{:index index :buffer buffer}))

(defn read
  "Reads the next bencoded value from the reader, returns null if there is no
  data left to read. If the keyword-dicts value is true then the keys of
  dictionaries will be turned into keywords (the default is true)."
  [reader-in &opt keyword-dicts]
  (read-bencode
   (if (nil? keyword-dicts) true keyword-dicts)
   reader-in))

(defn read-buffer
  "Reads the first bencoded value from the provided buffer, returns null if
  there is no data to read. If the keyword-dicts value is true then the keys of
  dictionaries will be turned into keywords (the default is true)."
  [buffer-in &opt keyword-dicts]
  (let [reader-in (reader buffer-in)]
    (read reader-in keyword-dicts)))

(defn- write-integer
  "Writes the bencoded representation of the provided integer to the buffer."
  [buffer-out int-in]
  (buffer/push-byte buffer-out INT-FLAG)
  (buffer/push-string buffer-out (string int-in))
  (buffer/push-byte buffer-out END-FLAG))

(defn- write-string
  "Writes the bencoded represnetation of the provided string to the buffer."
  [buffer-out string-in]
  (buffer/push-string buffer-out (string (length string-in)))
  (buffer/push-byte buffer-out LENGTH-SEPARATOR)
  (buffer/push-string buffer-out string-in))

(defn- write-list
  "Writes the bencoded representation of the provide list to the buffer,
  the write-fn is used to encoded nested structures."
  [write-fn buffer-out list-in]
  (buffer/push-byte buffer-out LIST-FLAG)
  (let [sorted-in (sort-by string (apply array list-in))]
    (seq [index :range [0 (length sorted-in)]]
         (write-fn buffer-out (get sorted-in index))))
  (buffer/push-byte buffer-out END-FLAG))

(defn- write-map
  "Writes the bencoded representation of the provided map to the buffer, the
  write-fn is used to encode nested structures. Keywords are transformed into
  strings (i.e. \":key\" becomes \"key\")."
  [write-fn buffer-out map-in]
  (buffer/push-byte buffer-out DICTIONARY-FLAG)
  (let [sort-fn (fn [pair] (string (first pair)))
        sorted-map (sort-by sort-fn (pairs map-in))]
    (seq [index :range [0 (length sorted-map)]]
         (buffer (write-string buffer-out (first (get sorted-map index)))
                 (write-fn buffer-out (last (get sorted-map index))))))
  (buffer/push-byte buffer-out END-FLAG))

(defn write-buffer
  "Write the bencoded representation of the data structure to the provided
  buffer, keywords will be turned into strings (i.e. \":key\" becomes \"key\")."
  [buffer-out data]
  (cond
    (int? data)
    (write-integer buffer-out data)

    (or (string? data) (buffer? data))
    (write-string buffer-out data)

    (or (array? data) (tuple? data))
    (write-list write-buffer buffer-out data)

    (or (table? data) (struct? data))
    (write-map write-buffer buffer-out data)

    (write-error "Unknown type" data)))

(defn write
  "Returns a buffer with the bencoded representation of the data structure,
  keywords will be turned into strings (i.e. \":key\" becomes \"key\")."
  [data]
  (let [buffer-out @""]
    (write-buffer buffer-out data)))
