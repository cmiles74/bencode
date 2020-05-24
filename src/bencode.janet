
#
# Provides functions for encoding and decoting data in the bencode format.
#
# Modeled heavly on thr nrepl/bencode project
#    https://github.com/nrepl/bencode
#
# read-netstring
# write-netstring
# read-bencode
# write-bencode

(def MINUS 41)
(def INT-FLAG 105)
(def END-FLAG 101)
(def LENGTH-FLAG 108)
(def LENGTH-SEPARATOR 58)

(defn reader
  "Returns a reader for the buffer"
  [buffer &opt index-in]
  (let [index (if-not (nil? index-in) index-in 0)]
    @{:index index :buffer buffer}))

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
  "Returns the byte at the reader's current index and advanced the index"
  [reader-in]
  (if (end? reader-in)
    (error "Read past the end of the buffer")
    (let [input (peek-byte reader-in)]
      (put reader-in :index (+ (get reader-in :index) 1))
      input)))

(defn match
  "If the reader's next byte  matches the provided byte, advances the reader"
  [reader-in byte]
  (cond
    (= byte (peek-byte reader-in)) (read-byte reader-in)
    (end? reader-in) false
    false))

(defn digit?
  "Returns true if the provided byte represents a digit"
  [byte]
  (if (and (< 47 byte) (> 58 byte)) true false))

(defn read-integer
  "Reads the next integer from the buffer"
  [reader-in]
  (let [buffer-out (buffer/new 0)]

    # check to see if the number is signed
    (if (= MINUS (peek-byte reader-in))
      (buffer/push-byte buffer-out reader-in))

    # read all of the digits
    (while (digit? (peek-byte reader-in))
      (buffer/push-byte buffer-out (read-byte reader-in)))
    (scan-number buffer-out)))

(defn parse-error
  "Throws an error with the provided message for the given reader"
  [message reader-in]
  (error (string message " at index " (get reader-in :index))))

(defn read-bencode-integer
  "Reads a bencoded integer from the reader"
  [reader-in]
  (if-not (match reader-in INT-FLAG)
    (parse-error "No integer found" reader-in))
  (let [int-in (read-integer reader-in)]
    (print int-in)
    (if-not (match reader-in END-FLAG)
      (parse-error "Unterminated integer" reader-in))
    int-in))

(defn read-bencode-string
  "Reads a bencoded binary string from the reader"
  [reader-in]
  (if-not (digit? (peek-byte reader-in))
    (parse-error "No length found for string" reader-in))

  (let [length (read-integer reader-in)
        buffer-out (buffer/new 0)]

    (if (<= length 0)
      (parse-error "String length must be greater than 0" reader-in))

    (if-not (match reader-in LENGTH-SEPARATOR)
      (parse-error "No separator \":\" after string length" reader-in))

    (for count 0 length
      (buffer/push-byte buffer-out (read-byte reader-in)))
    buffer-out))

(defn read-bencode
  "Reads the next bencoded value from the reader"
  [reader-in]
  (cond
    (= INT-FLAG (peek-byte reader-in)) (read-bencode-integer reader-in)
    (digit? (peek-byte reader-in)) (read-bencode-string reader-in)))
