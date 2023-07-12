(fn fn> [...]
  "Create a type checked function."
  (let [args [...]
        has-name? (sym? (. args 1))
        name (if has-name? (. args 1) nil)
        arglist (if has-name? (. args 2) (. args 1))
        return-type (if has-name? (. args 3) (. args 2))
        body args

        new-arglist []
        assertions `(do (local typed# (require :typed-fennel)))
        new-fn `(fn)]
    (assert-compile (= :table (type arglist)) "expected parameters table")
    (assert-compile (= 0 (% (length arglist) 2)) "expected an even number of parameters/types")
    (assert-compile (= :table (type return-type)) "expected a return type table")

    ;; remove name, arglist and return type from body
    (when has-name?
      (table.remove body 1))
    (table.remove body 1)
    (table.remove body 1)

    ;; build list of argument type assertions and new arglist
    (for [i 1 (length arglist) 2]
      (tset
        assertions
        (+ 1 (length assertions))
        `(assert (typed#.has-type? ,(. arglist i) ,(. arglist (+ 1 i)))))
      (tset
        new-arglist
        (+ 1 (length new-arglist))
        (. arglist i)))

    ;; construct fn
    (when has-name?
      (tset new-fn (+ 1 (length new-fn)) name))
    (tset new-fn (+ 1 (length new-fn)) new-arglist)
    (tset new-fn (+ 1 (length new-fn)) assertions)
    (tset new-fn (+ 1 (length new-fn))
      `(let [return-type# ,return-type
             return# [(do ,(unpack body))]]
         (local typed# (require :typed-fennel))
         (assert (typed#.has-type? return# return-type#))
         (table.unpack return#)))

    new-fn))


{:fn> fn>}
