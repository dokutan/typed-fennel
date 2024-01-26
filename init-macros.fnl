;; fennel-ls: macro-file

(fn fn> [...]
  "Create a type checked function."
  (let [args        [...]
        has-name?   (sym? (. args 1))
        name        (if has-name? (. args 1) nil)
        arglist     (if has-name? (. args 2) (. args 1))
        return-type (if has-name? (. args 3) (. args 2))
        docstring   (if
                      (and
                        has-name?
                        (> (length args) 4)
                        (= :string (type (. args 4)))) (. args 4)
                      (and
                        (> (length args) 3)
                        (= :string (type (. args 3)))) (. args 3))
        metadata    (if
                      (and
                        has-name?
                        docstring
                        (> (length args) 5)
                        (table? (. args 5))) (. args 5)
                      (and
                        (or has-name? docstring)
                        (> (length args) 4)
                        (table? (. args 4))) (. args 4)
                      (and
                        (not has-name?)
                        (not docstring)
                        (> (length args) 3)
                        (table? (. args 3))) (. args 3))
        body        args
        new-arglist []
        assertions  `(do (local typed# (require :typed-fennel)))
        new-fn      `(fn)]

    (assert-compile (= :table (type arglist)) "expected parameters table")
    (assert-compile (= :table (type return-type)) "expected a return type table")

    ;; remove name, arglist and return type from body
    (when has-name?
      (table.remove body 1))
    (table.remove body 1)
    (table.remove body 1)

    ;; remove docstring and metadata from body
    (when (or docstring metadata)
      (table.remove body 1))
    (when (and docstring metadata)
      (table.remove body 1))

    ;; build list of argument type assertions and new arglist
    (var i 1)
    (while (<= i (length arglist))
      (if
        (and (sym? (. arglist i)) (= "&" (. arglist i 1)))
        (do
          (table.insert new-arglist (. arglist i))
          (set i (+ 1 i)))

        ; else
        (do
          (assert-compile (. arglist (+ i 1)) "expected a type for every parameter")
          (table.insert
            assertions
            `(assert
              (typed#.has-type? ,(. arglist i) ,(. arglist (+ 1 i)))
                (..
                  "argument " ,(tostring (. arglist i)) " of "
                  (if ,has-name?
                    (.. "fn> " ,(tostring name) ":")
                    "anonymous fn>:")
                  " received " (type ,(. arglist i))
                  ", expected " (tostring ,(. arglist (+ 1 i))))))
          (table.insert new-arglist (. arglist i))
          (set i (+ 2 i)))))

    ;; construct fn
    (when has-name?
      (table.insert new-fn name))
    (table.insert new-fn new-arglist)
    (when docstring
      (table.insert new-fn docstring))
    (when metadata
      (table.insert new-fn metadata))
    (table.insert new-fn assertions)
    (table.insert new-fn
      `(let [return-type# ,return-type
             return-values# [(do ,(unpack body))]]
         (local typed# (require :typed-fennel))
         (assert
          (typed#.has-type? return-values# return-type#)
          (..
            "wrong return type of "
            (if ,has-name?
              (.. "fn> " ,(tostring name))
              "anonymous fn>")))
         (,(if table.unpack `table.unpack `unpack) return-values#)))

    new-fn))

(fn let> [bindings & body]
  "Type checked version of `let`."
  (let [new-bindings `[typed# (require :typed-fennel)]
        new-let `(let)]

    (assert-compile (sequence? bindings) "expected binding sequence")
    (assert-compile (= 0 (% (length bindings) 3)) "expected name/type/value triples")

    (for [i 1 (length bindings) 3]
      (table.insert new-bindings (. bindings i))
      (table.insert new-bindings (. bindings (+ 2 i)))

      (if
        (or (list? (. bindings i)) (sequence? (. bindings i)))
        (do
          (var j 1)
          (local assertions `(do))

          (each [_ name (ipairs (. bindings i))]
            (when (and (sym? name) (not (= :& (. name 1))))
              (table.insert assertions
                `(assert
                    (typed#.has-type? ,name ,(. bindings (+ 1 i) j))
                    (.. "let> " ,(tostring name) ": received "
                        (type ,name) ", expected " ,(tostring (. bindings (+ 1 i) j)))))
              (set j (+ 1 j))))

          (table.insert new-bindings `_#)
          (table.insert new-bindings assertions))

        (sym? (. bindings i))
        (do
          (table.insert new-bindings `_#)
          (table.insert new-bindings
            `(assert
              (typed#.has-type? ,(. bindings i) ,(. bindings (+ 1 i)))
              ,(.. "let> " (tostring (. bindings i)) ": received " (type (. bindings (+ 2 i)))
                   ", expected " (tostring (. bindings (+ 1 i)))))))

        (= :table (type (. bindings i))) ; kv table
        (do
          (var j 1)
          (local assertions `(do))

          (each [_ name (pairs (. bindings i))]
            (when (and (sym? name) (not (= :&as (. name 1))))
              (table.insert assertions
                `(assert
                    (typed#.has-type? ,name ,(. bindings (+ 1 i) j))
                    (.. "let> " ,(tostring name) ": received "
                        (type ,name) ", expected " ,(tostring (. bindings (+ 1 i) j)))))
              (set j (+ 1 j))))

          (table.insert new-bindings `_#)
          (table.insert new-bindings assertions))))

    (tset new-let 2 new-bindings)
    (tset new-let 3 `(do ,(unpack body)))

    new-let))

(fn var-local> [form name typ value]
  "Type checked version of `local` and `var`."
  (let [assertions `(let [typed# (require :typed-fennel)])]

    (if
      (or (list? name) (sequence? name))
      (do
        (var j 1)
        (each [_ n (ipairs name)]
          (when (and (sym? n) (not (= :& (. n 1))))
            (table.insert assertions
              `(assert
                  (typed#.has-type? ,n ,(. typ j))
                  (.. ,form " " ,(tostring n) ": received "
                       (type ,n) ", expected " ,(tostring (. typ j)))))
            (set j (+ 1 j)))))

      (sym? name)
      (table.insert assertions
        `(assert
          (typed#.has-type? ,name ,typ)
          ,(.. form " " (tostring name) ": received "
               (type value) ", expected " (tostring typ))))

      (= :table (type name)) ; kv table
      (do
        (var j 1)
        (each [_ n (pairs name)]
          (when (and (sym? n) (not (= :&as (. n 1))))
            (table.insert assertions
              `(assert
                  (typed#.has-type? ,n ,(. typ j))
                  (.. ,form " " ,(tostring n) ": received "
                      (type ,n) ", expected " ,(tostring (. typ j)))))
            (set j (+ 1 j))))))

    `(values
      (,(sym form) ,name ,value)
      ,assertions)))

(local var> (partial var-local> :var))
(local local> (partial var-local> :local))

{: fn> : let> : var> : local>}
