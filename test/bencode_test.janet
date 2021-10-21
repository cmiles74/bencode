(import tester :prefix "")
(import "../src/bencode")

(def read bencode/read-buffer)

(defn string-ish?
  "Returns true if x is a string or buffer"
  [x]
  (or (string? x) (buffer? x) (keyword? x)))

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
  have the same values. If they are maps, then they must have the same keys with
  the same values."
  [a b]
  (cond
    (and (int? a) (int? b))
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
         (let [sort-fn (fn [pair] (string (first pair)))
               sa (sort-by sort-fn (pairs a))
               sb (sort-by sort-fn (pairs b))]
           (last (seq [index :range [0 (length a)]
                       :while (same? (get sa index)
                                     (get sb index))]
                      index)))))

    (= a b)))

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
  "Read bencoded data"
  (test "Read integer 1"
        (= 0 (read "i0e")))

  (test "Read integer 2"
        (= 42 (read "i42e")))

  (test "Read integer 3"
        (= -42 (read "i-42e")))

  (test "Read bencoded string 1"
        (= "Hello, World!"
           (read "13:Hello, World!")))

  (test "Read bencoded string 2"
        (= "Hällö, Würld!"
           (read "16:Hällö, Würld!")))

  (test "Read bencoded string 3"
        (= "Здравей, Свят!"
           (read "25:Здравей, Свят!")))

  (test "Read empty bencoded string"
        (same? ""
               (read "0:")))

  (test "Read list 1"
        (= []
           (read "le")))

  (test "Read list 2"
        (= ["cheese"]
           (read "l6:cheesee")))

  (test "Read list 3"
        (= ["cheese" "ham" "eggs"]
           (read "l6:cheese3:ham4:eggse")))

  (test "Read list with empty string"
        (same? @[@"cheese" @"" @"eggs" @"ham"]
               (read "l6:cheese0:3:ham4:eggse")))

  (test "Read map 1"
        (= {}
           (read "de")))

  (test "Read map 2"
        (= {:ham "eggs"}
           (read "d3:ham4:eggse")))

  (test "Read map 3"
        (= {:ham "eggs" :cost 5}
           (read "d4:costi5e3:ham4:eggse")))

  (test "Read map with empty string value"
        (same? @{:ham @"eggs" :cost 5 :code @""}
               (read "d4:costi5e3:ham4:eggs4:code0:e")))

  (test "Read nested list"
        (= ["cheese" "ham" "eggs" ["salt" "pepper"]
            {:rice "white" :beans "kidney"}]
           (read "l6:cheese3:ham4:eggsl4:salt6:peppered4:rice5:white5:beans6:kidneyee")))

  (test "Read nested map"
        (= {:cost 5 :for ["finn" "joanna" "emily"] :ham "eggs" :map
            {:apple "red" :pear "green"}}
           (read "d3:ham4:eggs4:costi5e3:forl4:finn6:joanna5:emilye3:mapd5:apple3:red4:pear5:greenee")))

  (test "Read nested map and return mutable values"
        (same? @{:cost 5 :for @[@"emily" @"finn" @"joanna"] @"ham" @"eggs" @"map"
                @{:apple @"red" :pear @"green"}}
               (read
                "d3:ham4:eggs4:costi5e3:forl4:finn6:joanna5:emilye3:mapd5:apple3:red4:pear5:greenee"
                :return-mutable true)))

  (test "Read nested map and do not convert keys to keywords"
        (= {"cost" 5 "for" ["finn" "joanna" "emily"] "ham" "eggs" "map"
            {"apple" "red" "pear" "green"}}
           (read
            "d3:ham4:eggs4:costi5e3:forl4:finn6:joanna5:emilye3:mapd5:apple3:red4:pear5:greenee"
            :keyword-dicts false)))

  (let [reader (bencode/reader "13:Hello, World!13:Hello, World!")]
    (loop [value :iterate (bencode/read reader)]
      (test "Read several values"
            (= "Hello, World!" value))))

  (let [reader (bencode/reader "13:Hello, World!\n\n13:Hello, World!")]
    (loop [value :iterate (bencode/read reader :ignore-newlines true)]
      (test "Read several values divided by newlines"
            (= "Hello, World!" value))))

  (test "Write integer 1"
        (let [bencoded (bencode/write 0)]
          (same? "i0e" bencoded)))

  (test "Write integer 2"
        (let [bencoded (bencode/write 42)]
          (same? "i42e" bencoded)))

  (test "Write integer 3"
        (let [bencoded (bencode/write -42)]
          (same? "i-42e" bencoded)))

  (test "Write string 1"
        (let [bencoded (bencode/write "Hello, World!")]
          (same? "13:Hello, World!" bencoded)))

  (test "Write string 2"
        (let [bencoded (bencode/write "Hällö, Würld!")]
          (same? "16:Hällö, Würld!" bencoded)))

  (test "Write string 3"
        (let [bencoded (bencode/write "Здравей, Свят!")]
          (same? "25:Здравей, Свят!" bencoded)))

  (test "Write list 1"
        (let [bencoded (bencode/write (array/new 0))]
          (same? "le" bencoded)))

  (test "Write list 2"
        (let [bencoded (bencode/write ["cheese"])]
              (same? "l6:cheesee" bencoded)))

  (test "Write list 3"
        (let [bencoded (bencode/write ["cheese" "eggs" "ham"])]
          (same? "l6:cheese4:eggs3:hame" bencoded)))

  (test "Write Map 1"
        (let [bencoded (bencode/write {})]
          (same? "de" bencoded)))

  (test "Write Map 2"
        (let [bencoded (bencode/write {"ham" "eggs"})]
          (same? "d3:ham4:eggse" bencoded)))

  (test "Write Map 3"
        (let [bencoded (bencode/write {"ham" "eggs" "cost" 5})]
          (same? "d4:costi5e3:ham4:eggse" bencoded)))

  (test "Write nested list"
        (let [bencoded (bencode/write [{"rice" "white" "beans" "kidney"} ["pepper" "salt"]
                                       "cheese" "eggs"  "ham"])]
          (same? "ld5:beans6:kidney4:rice5:whiteel6:pepper4:salte6:cheese4:eggs3:hame"
                 bencoded)))

  (test "Write nested map"
        (let [bencoded (bencode/write {"cost" 5 "for" ["emily" "finn" "joanna"] "ham" "eggs" "map"
                                       {"apple" "red" "pear" "green"}})]
          (same? "d4:costi5e3:forl5:emily4:finn6:joannae3:ham4:eggs3:mapd5:apple3:red4:pear5:greenee"
                 bencoded)))

  (test "Write nested map in strict-conversion mode"
        (let [bencoded (bencode/write {:cost 5 :for ["emily" "finn" "joanna"] :ham "eggs" :map
                                       {"apple" "red" "pear" "green"}}
                                      :strict-conversion true)]
          (same? "d4:costi5e3:forl5:emily4:finn6:joannae3:ham4:eggs3:mapd5:apple3:red4:pear5:greenee"
                 bencoded)))

  (test "Write nested map in strict-conversion mode with not convertible data"
        (do
          (def [success? _] (protect (bencode/write :key :strict-conversion true)))
          (not success?)))

  (test "Write nested map with keywords or symbols"
        (let [bencoded (bencode/write {"cost" 5 "for" [:emily 'finn "joanna"] :ham :eggs 'map
                                       {"apple" "red" "pear" "green"}})]
          (same? "d4:costi5e3:forl5:emily4:finn6:joannae3:ham4:eggs3:mapd5:apple3:red4:pear5:greenee"
                 bencoded))))
