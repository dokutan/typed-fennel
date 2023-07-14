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
    (assert-compile (= 0 (% (length arglist) 2)) "expected an even number of parameters/types")
    (assert-compile (= :table (type return-type)) "expected a return type table")

    ;; remove name, arglist and return type from body
    (when has-name?
      (table.remove body 1))
    (table.remove body 1)
    (table.remove body 1)

    ;; remove docstring and metadata from body
    (when (and docstring metadata)
      (table.remove body 1)
      (table.remove body 1))
    (when (or
            (and (not docstring) metadata)
            (and docstring (not metadata)))
      (table.remove body 1))

    ;; build list of argument type assertions and new arglist
    (for [i 1 (length arglist) 2]
      (tset
        assertions
        (+ 1 (length assertions))
        `(assert
          (typed#.has-type? ,(. arglist i) ,(. arglist (+ 1 i)))
          (..
            "argument " ,(tostring (. arglist i)) " of "
            (if ,has-name?
              (.. "fn> " ,(tostring name) ":")
              "anonymous fn>:")
            " received " (type ,(. arglist i))
            ", expected " (tostring ,(. arglist (+ 1 i))))))
      (tset
        new-arglist
        (+ 1 (length new-arglist))
        (. arglist i)))

    ;; construct fn
    (when has-name?
      (tset new-fn (+ 1 (length new-fn)) name))
    (tset new-fn (+ 1 (length new-fn)) new-arglist)
    (when docstring
      (tset new-fn (+ 1 (length new-fn)) docstring))
    (when metadata
      (tset new-fn (+ 1 (length new-fn)) metadata))
    (tset new-fn (+ 1 (length new-fn)) assertions)
    (tset new-fn (+ 1 (length new-fn))
      `(let [return-type# ,return-type
             return# [(do ,(unpack body))]]
         (local typed# (require :typed-fennel))
         (assert
          (typed#.has-type? return# return-type#)
          (..
            "wrong return type of "
            (if ,has-name?
              (.. "fn> " ,(tostring name))
              "anonymous fn>")))
         (unpack return#)))

    new-fn))

(fn let> [bindings & body]
  "Type checked version of `let`."
  (let [new-bindings `[typed# (require :typed-fennel)]
        new-let `(let)]

    (assert-compile (sequence? bindings) "expected binding sequence")
    (assert-compile (= 0 (% (length bindings) 3)) "expected name/type/value triples")

    (for [i 1 (length bindings) 3]
      (tset new-bindings (+ 1 (length new-bindings)) (. bindings i))
      (tset new-bindings (+ 1 (length new-bindings)) (. bindings (+ 2 i)))
      (tset new-bindings (+ 1 (length new-bindings)) `_#)
      (tset new-bindings (+ 1 (length new-bindings))
        `(assert
           (typed#.has-type? ,(. bindings i) ,(. bindings (+ 1 i))))))

    (tset new-let 2 new-bindings)
    (tset new-let 3 `(do ,(unpack body)))

    new-let))

{: fn> : let>}
