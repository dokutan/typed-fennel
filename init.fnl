(fn has-type? [value t]
  "Check if `value` has type `t`."
  (if
    (= :any t)
    true

    (or
      (= :integer t)
      (= :float t))
    (= t (math.type value))

    (= :file t)
    (= :file (io.type value))

    (= :closed-file t)
    (= "closed file" (io.type value))

    (= :table (type t))
    (accumulate [result (= :table (type value))
                 k v (pairs t)]
      (and result (has-type? (. value k) v)))

    (= :function (type t))
    (if (t value) true false)

    :else
    (= t (type value))))

(fn intersection [...]
  "Create an intersection type."
  (let [types [...]]
    (fn [value]
      (accumulate [result true
                   _ t (ipairs types)]
          (and result (has-type? value t))))))

(fn union [...]
  "Create a union type."
  (let [types [...]]
    (fn [value]
      (accumulate [result false
                   _ t (ipairs types)]
          (or result (has-type? value t))))))

{: has-type?
 : intersection
 : union}
