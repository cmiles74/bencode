(import tester :prefix "")
(import "src/bencode" :as "b")


(defn read
  "Reads the provided bencoded string"
  [text]
  (b/read (b/reader text)))

(defn read-string
  "Reads the provided bencoded string and returns a string with the value"
  [text]
  (string (read text)))

(defn array-same?
  "Returns true if both arrays are of the same length and content"
  [a b]
  (if (= (length a) (length b))
    true
    false))

(deftest
  "Read strings"
  (test "Read bencoded string 1"
        (= "Hello, World!"
           (read-string "13:Hello, World!")))

  (test "Read bencoded string 2"
        (= "Hällö, Würld!"
           (read-string "16:Hällö, Würld!")))

  (test "Read bencoded string 3"
        (= "Здравей, Свят!"
           (read-string "25:Здравей, Свят!")))

  (test "Read integer 1"
        (= 0 (read "i0e")))

  (test "Read integer 2"
        (= 42 (read "i42e")))

  (test "Read integer 1"
        (= -42 (read "i-42e")))

  (test "Read list"
        (array-same? (array/new 0)
                     (read "le")))

  )

