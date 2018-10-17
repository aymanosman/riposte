#lang racket/base

(require (for-syntax racket/base)
         racket/cmdline
         dotenv
         (file "util.rkt")
         (only-in (file "evaluator.rkt")
                  eval-program)
         (only-in (file "environment.rkt")
                  environment?
                  make-fresh-environment)
         (file "check.rkt")
         (only-in (file "program.rkt")
                  file->program)
         (only-in (file "parameters.rkt")
                  param-cwd)
         racket/contract
         brag/support
         racket/match)

(define/contract version
  string?
  "0.1.2")

(define/contract opt-version
  parameter?
  (make-parameter #f))

(define/contract opt-lint
  parameter?
  (make-parameter #f))

(define/contract opt-dotenvs
  parameter?
  (make-parameter (list)))

(define/contract (default-error-handler e)
  (exn? . -> . any)
  (log-error "~a" (exn-message e))
  (exit 1))

(define-syntax (run! stx)
  (syntax-case stx ()
    [(_ #:error-handler handler steps ...)
     #'(with-handlers ([exn? handler])
         (begin0
             (void)
           `@(list steps ...)))]
    [(_ steps ...)
     #'(with-handlers ([exn? default-error-handler])
         (begin0
             (void)
           `@(list steps ...)))]))

(define/contract (check-dotenvs dotenvs)
  ((listof string?) . -> . void)
  (for ([f dotenvs])
    (define p (build-path 'same f))
    (unless (file-exists? p)
      (error "Cannot read environment file ~a" (path->string p))
      (exit 1))))

(define (fail-program e)
  (displayln (format "FAIL: ~a" (exn-message e)))
  (exit 1))

(define/contract (eval-program-in-dir dir file-to-process)
  (path? path-string? . -> . environment?)
  (parameterize ([param-cwd dir])
    (eval-program (file->program file-to-process))))

(module+ main

  (define file-to-process
    (command-line
     #:program "riposte"
     #:once-each
     [("--version") "Print the version"
                    (opt-version #t)]
     [("--lint") "Check a Riposte file"
                 (opt-lint #t)]
     #:multi
     [("--env") f
                "Specify an environment file to use (can be specified multiple times)"
                (opt-dotenvs (cons f (opt-dotenvs)))]
     #:args args
     args))

  (when (opt-version)
    (displayln (format "~a" version))
    (exit 0))

  (match file-to-process
    [(list filename)
     (set! file-to-process
           filename)]
    [else
     (displayln (format "Cannot make sense of commandline argument: ~a" file-to-process))
     (exit 1)])

  (unless (file-exists? file-to-process)
    (displayln (format "No such file: ~a" file-to-process))
    (exit 1))

  (define-values (dir base is-directory?)
    (split-path file-to-process))

  (when is-directory?
    (displayln (format "Given file is actually a directory: ~a" file-to-process))
    (exit 1))

  (run! (check-dotenvs (opt-dotenvs)))

  (run! (dotenv-load! (opt-dotenvs)))

  (run! #:error-handler fail-program
        (eval-program-in-dir dir file-to-process)))
