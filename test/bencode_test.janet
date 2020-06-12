(import tester :prefix "")
(import "src/bencode" :as "bencode")

(defn string-ish?
  "Returns true if x is a string or buffer"
  [x]
  (or (string? x) (buffer? x)))

(defn list?
  "Returns true if x is an array or tuple"
  [x]
  (or (array? x) (tuple? x)))

(defn map?
  "Returns true if x is a struct or table"
  [x]
  (or (struct? x) (table? x)))

(defn same?
  "Returns true if both x and y are the same. If they are lists, then they must
  have the same values in the same order. If they are maps, then they must have
  the same keys with the same values in the same order."
  [a b]
  (cond
    (and (number? a) (number? b))
    (= a b)

    (and (string-ish? a) (string-ish? b))
    (= (string a) (string b))

    (and (list? a) (list? b))
    (cond
      (= 0 (length a) (length b))
      true

      (= (- (length a) 1)
         (let [sa (sort-by string (apply array a))
               sb (sort-by string (apply array b))]
           (last (seq [index :range [0 (length sa)]
                       :while (same? (get sa index)
                                     (get sb index))]
                      index)))))

    (and (map? a) (map? b))
    (cond
      (= 0 (length a) (length b))
      true

      (= (- (length a) 1)
         (let [sort-fn (fn [pair] (string (first pair)))]
           (last (seq [index :range [0 (length a)]
                       :while (same? (get (sort-by sort-fn (pairs a)) index)
                                     (get (sort-by sort-fn (pairs b)) index))]
                      index)))))

    (= a b)))

(defn read
  "Reads the provided buffer of bencoded data, doesn't turn dictionary keys
  into keywords."
  [buffer-in]
  (bencode/read-buffer buffer-in false))

(defmacro time
  "Calculates and prints how long it took to execute the provided expression
  and returns the result of that expression."
  [expression]
  (with-syms [start result]
    ~(let [,start (os/clock)
           ,result ,expression]
       (print (string "Elapsed time: " (- (os/clock) ,start) " sec"))
       ,result)))

(deftest
  "Read strings"
  (test "Read bencoded string 1"
        (same? "Hello, World!"
           (read "13:Hello, World!")))

  (test "Read bencoded string 2"
        (same? "Hällö, Würld!"
           (read "16:Hällö, Würld!")))

  (test "Read bencoded string 3"
        (same? "Здравей, Свят!"
           (read "25:Здравей, Свят!")))

  (test "Read integer 1"
        (same? 0 (read "i0e")))

  (test "Read integer 2"
        (same? 42 (read "i42e")))

  (test "Read integer 3"
        (same? -42 (read "i-42e")))

  (test "Read list 1"
        (same? (array/new 0)
               (read "le")))

  (test "Read list 2"
        (same? ["cheese"]
               (read "l6:cheesee")))

  (test "Read list 3"
        (same? ["cheese" "eggs" "ham"]
               (read "l6:cheese3:ham4:eggse")))

  (test "Read map 1"
        (same? {}
               (read "de")))

  (test "Read map 2"
        (same? {"ham" "eggs"}
               (read "d3:ham4:eggse")))

  (test "Read map 3"
        (same? {"ham" "eggs" "cost" 5}
               (read "d3:ham4:eggs4:costi5ee")))

  (test "Read nested list"
        (same? [{"rice" "white" "beans" "kidney"} ["pepper" "salt"]
                "cheese" "eggs"  "ham"]
               (read "l6:cheese3:ham4:eggsl4:salt6:peppered4:rice5:white5:beans6:kidneyee")))

  (test "Read nested map"
        (same? {"cost" 5 "for" ["emily" "finn" "joanna"] "ham" "eggs" "map"
                {"apple" "red" "pear" "green"}}
               (read "d3:ham4:eggs4:costi5e3:forl4:finn6:joanna5:emilye3:mapd5:apple3:red4:pear5:greenee"))))

