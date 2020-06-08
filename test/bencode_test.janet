
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
  "Returns true if both arrays are of the same length and content in the same
  order. The prep-fn will be applied to values of each array before they are
  compared."
  [a b &opt prep-fn]
  (cond
    (= 0 (length a) (length b))
    true

    (= (length a) (length b))
    (= (- (length a) 1)
       (let [prep-fn-this (if (nil? prep-fn) identity prep-fn)]
         (last (seq [index :range [0 (length a)]
                     :while (= (prep-fn-this (get a index))
                               (prep-fn-this (get b index)))]
                    index))))

    false))

(defn array-string-same?
  "Returns true if both arrays are of the same length and contain the same set
  of strings in the same order."
  [a b]
  (array-same? a b string))

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

  (test "Read list 1"
        (array-same? (array/new 0)
                     (read "le")))

  (test "Read list 2"
        (array-string-same? @["cheese"]
                     (read "l6:cheesee")))

  (test "Read list 3"
        (array-string-same? @["cheese" "ham" "eggs"]
                     (read "l6:cheese3:ham4:eggse")))

  )

