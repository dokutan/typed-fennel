# typed-fennel
Adding dynamic type checking to Fennel.
This library contains replacements for common built-in forms that accept type annotations and perform type checking at runtime.

## Installation
Clone this repository and place it in your package path, e.g. the directory containing your code.

```sh
git clone https://github.com/dokutan/typed-fennel
```

## Usage

```fennel
(import-macros {: fn>} :typed-fennel)
(local {: has-type?} (require :typed-fennel))

;; simple type checking
(has-type? 1 :integer)        ; => true
(has-type? 1 :float)          ; => false
(has-type? [1 2] [:any :any]) ; => true

;; create a type checked function
(fn> inc [a :number] [:number] (+ a 1))
(inc 1)   ; => 2
(inc "1") ; => runtime error

;; use let>, local> and var> for type checking
(var> x :string "hello")
(let> [a :number 10
       b :number 20]
  (+ a b))

;; destructuring is supported by all macros
(local> (a b) [:string :any] (foo))
(fn [a & rest] [:any :table]
  (print a))
```

## Type system

### Primitive types
The available primitive types are based on the normal Fennel/Lua types, with some additions. They are represented as strings.

- nil
- string
- number
- boolean
- table
- function
- thread
- userdata
- integer
- float
- file
- closed-file
- any

### Table types
Tables of types can be used to describe tables:

```fennel
(local {: has-type?} (require :typed-fennel))

(has-type? [1] [:number :number])     ; => false
(has-type? [1 2] [:number :number])   ; => true
(has-type? [1 2 3] [:number :number]) ; => true

(has-type? [1 [2]] [:number [:number]]) ; => true

(has-type? {:x 1 :y 2} {:x :number :y :number}) ; => true
```

### Type functions
Any function that takes at least one value and returns a truthy value can be used as a type.

```fennel
(import-macros {: fn>} :typed-fennel)
(local {: has-type?} (require :typed-fennel))

(fn weekday [value]
  "A weekday enum"
  (.
    {:monday     true
      :tuesday   true
      :wednesday true
      :thursday  true
      :friday    true
      :saturday  true
      :sunday    true}
    value))
(has-type? :monday weekday) ; => true

(fn positive-int [value]
  "A positive integer type"
  (and
    (has-type? value :integer)
    (>= value 0)))
(has-type? 1 positive-int)  ; => true
(has-type? -1 positive-int) ; => false

(fn byte [value]
  "A bounded type: 0-255"
  (>= 255 value 0))
(has-type? 255 byte) ; => true
(has-type? 256 byte) ; => false
```

### Union types
Union types can be constructed using the ``union`` function:

```fennel
(import-macros {: fn>} :typed-fennel)
(local {: has-type? : union} (require :typed-fennel))

(local number-or-string (union :number :string))
(has-type? 1 number-or-string)   ; => true
(has-type? "1" number-or-string) ; => true

(fn> length2 [a (union :string :table)] [:integer] (length a))
(length2 "123") ; => 3
(length2 123)   ; => runtime error
```

### Intersection types
Union types can be constructed using the ``intersection`` function:

```fennel
(import-macros {: fn>} :typed-fennel)
(local {: has-type? : intersection} (require :typed-fennel))

(local ascii-char (intersection :string #(= 1 (length $))))
(has-type? :a ascii-char) ; => true
(has-type? :λ ascii-char) ; => false
```

### Using expressions as types
In the ``fn>`` macro any expression evaluating to a type can be used, this allows e.g. generics to be implemented.
When the macro is expanded, the expressions have access to the function parameters:

```fennel
(import-macros {: fn>} :typed-fennel)

(fn> tuple [a :any] [[(type a) (type a)]] [a a])

(fn> assert-same-type [a :any b (type a)] [:boolean] true)
(assert-same-type 1 2)   ; => true
(assert-same-type :1 :2) ; => true
(assert-same-type 1 :2)  ; => runtime error
```
