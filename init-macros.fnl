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
         (table.unpack return-values#)))

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
      (table.insert new-bindings `_#)
      (table.insert new-bindings
        `(assert
           (typed#.has-type? ,(. bindings i) ,(. bindings (+ 1 i))))))

    (tset new-let 2 new-bindings)
    (tset new-let 3 `(do ,(unpack body)))

    new-let))

{: fn> : let>}
