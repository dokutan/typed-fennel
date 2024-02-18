(fn has-type? [value t]
  "Check if `value` has type `t`."
  (if
    (= :any t)
    true

    (and
      (= :string (type t))
      (= :? (string.sub t 1 1)))
    (or
      (= nil value)
      (has-type? value (string.sub t 2)))

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

(fn enum [& vals]
  "Create an enum type."
  (let [vals (collect [_ v (ipairs vals)] (values v true))]
    (fn [value]
      (. vals value))))

(fn seq [T]
  "Create a sequential list type from type `T`."
  (fn [value]
    (if (= :table (type value))
      (accumulate [result true
                   _ v (ipairs value)]
        (and result (has-type? v T)))
      false)))

{: has-type?
 : intersection
 : union
 : enum
 : seq}
