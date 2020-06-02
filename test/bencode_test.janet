(import tester :prefix "")
(import "src/bencode" :as "b")

(deftest
  (test "Decode a map"
        (let [decoded (b/read (b/reader "d3:agei45e6:familyl6:joanna5:emily4:finne7:addressd3:zip5:01027ee"))]
          (and (= 45 (get decoded :age))
               (= "01027" (string (get (get decoded :address) :zip)))
               (= 3 (length (get decoded :family)))))))
