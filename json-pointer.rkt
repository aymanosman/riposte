#lang racket/base

(provide json-pointer-expression?
         make-json-pointer-expression)

(require racket/class
         racket/contract
         (only-in json-pointer
                  json-pointer-value
                  json-pointer-refers?)
         (only-in racket/port
                  with-output-to-string)
         (only-in ejs
                  ejsexpr?
                  ejsexpr->string
                  ejs-object?
                  ejs-array?)
         (only-in (file "expression.rkt")
                  expression?
                  expression%)
         (only-in (file "./identifier.rkt")
                  identifier-expression?)
         (only-in (file "environment.rkt")
                  environment-response))

(define json-pointer-expression%
  (class expression%
    (super-new)
    (init-field expr base)
    (define/override (evaluate env)
      (define doc
        (cond [(identifier-expression? base)
               (send base evaluate env)]
              [else
               (environment-response env)]))
      (when (and (not (ejs-object? doc))
                 (not (ejs-array? doc)))
        (error (cond [(identifier-expression? base)
                (format "~a is neither an array nor an object; cannot evaluate JSON Pointer expression \"~a\"."
                        (send base render)
                        expr)]
               [else
                (format "The previous response is neither an array nor an object; cannot evaluate JSON Pointer expression \"~a\"."
                        expr)])))
      (unless (json-pointer-refers? expr doc)
        (define new-message
          (with-output-to-string
            (lambda ()
              (displayln (format "JSON Pointer \"~a\" does not refer!" expr))
              (displayln (format "We evaluated the JSON Pointer relative to:"))
              (displayln (ejsexpr->string doc)))))
        (error new-message))
      (json-pointer-value expr doc))
    (define/override (render)
      expr)))

(define/contract (json-pointer-expression? x)
  (any/c . -> . boolean?)
  (and (object? x)
       (is-a? x json-pointer-expression%)))

(define/contract (make-json-pointer-expression jp base)
  (string? (or/c false/c identifier-expression?) . -> . json-pointer-expression?)
  (new json-pointer-expression%
       [expr jp]
       [base base]))
