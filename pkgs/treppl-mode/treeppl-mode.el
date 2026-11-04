;;; treeppl-mode.el -*- lexical-binding: t -*-

(require 'smie)

(eval-when-compile
  (require 'rx))
;; Please keep these lists sorted

(defconst treeppl--keywords
  '(
    "alias"
    "assume"
    "debug"
    "drift"
    "else"
    "for"
    "function"
    "if"
    "import"
    "in"
    "is"
    "let"
    "logWeight"
    "model"
    "observe"
    "resample"
    "return"
    "to"
    "type"
    "weight"
    ))

(defconst treeppl--builtin-functions
  '(
    ;; "Bernoulli"
    ;; "Beta"
    ;; "Binomial"
    ;; "Categorical"
    ;; "Chi2"
    ;; "Dirichlet"
    ;; "Empirical"
    ;; "Exponential"
    ;; "Gamma"
    ;; "Geometric"
    ;; "Multinomial"
    ;; "Normal"
    ;; "Poisson"
    ;; "Reciprocal"
    ;; "Uniform"
    ;; "UniformDiscrete"
    ))

(defconst treeppl--constants
  '(
    "true"
    "false"
    ))

(defconst treeppl-font-lock-keywords
  (list
   `(,(regexp-opt treeppl--keywords 'symbols) . font-lock-keyword-face)
   `(,(regexp-opt treeppl--builtin-functions 'symbols) . font-lock-builtin-face)
   `(,(regexp-opt treeppl--constants 'symbols) . font-lock-constant-face)

   `(,(rx word-start
          (group-n 1
            (or "let"
                "assume"
                "function"))
          (+ space)
          (group-n 2 (+ alnum))) (1 font-lock-keyword-face keep) (2 font-lock-variable-name-face) (3 font-lock-keyword-face keep t))

   ; numbers
   `(,(rx word-start (one-or-more digit) (opt "." (one-or-more digit))) . font-lock-constant-face)

   ; Types and constructors
   `(,(rx word-start upper (zero-or-more alnum) word-end) . font-lock-type-face)
  )
  "List of font lock keyword specifications to use in `treeppl-mode'.")

(defconst treeppl-mode-syntax-table
  (let ((table (make-syntax-table)))
    ;; Inline comment "// ..."
    ;; Block comment "/* ... */"
    (modify-syntax-entry ?* ". 23b" table)
    (modify-syntax-entry ?/ ". 124" table)
    (modify-syntax-entry ?\n "> " table)
    ;; Strings
    (modify-syntax-entry ?' "\"" table)
    ;; Grouping and blocks
    (modify-syntax-entry ?\{ "(}" table)
    (modify-syntax-entry ?\} "){" table)
    (modify-syntax-entry ?\[ "(]" table)
    (modify-syntax-entry ?\] ")[" table)
    (modify-syntax-entry ?\( "()" table)
    (modify-syntax-entry ?\) ")(" table)
    ;; Identifiers
    (modify-syntax-entry ?: "_" table)
    table)
  "Syntax table for `treeppl-mode'.")

(defun treeppl-indent-line ()
  "Indent current line."
  (let (indent
        boi-p                           ;begin of indent
        move-eol-p
        (point (point)))                ;lisps-2 are truly wonderful
    (save-excursion
      (back-to-indentation)
      (setq indent (car (syntax-ppss))
            boi-p (= point (point)))
      ;; don't indent empty lines if they don't have the in it
      (when (and (eq (char-after) ?\n)
                 (not boi-p))
        (setq indent 0))
      ;; check whether we want to move to the end of line
      (when boi-p
        (setq move-eol-p t))
      ;; decrement the indent if the first character on the line is a
      ;; closer.
      (when (or (eq (char-after) ?\))
                (eq (char-after) ?\}))
        (setq indent (1- indent)))
      ;; indent the line
      (delete-region (line-beginning-position)
                     (point))
      (indent-to (* tab-width indent)))
    (when move-eol-p
      (move-end-of-line nil))))

(define-derived-mode treeppl-mode prog-mode "treeppl"
  "Generic mode for editing MCore files."
  :syntax-table treeppl-mode-syntax-table
  (setq-local comment-start "//")
  (setq-local comment-end "")
  (smie-setup nil #'ignore)
  ;; (setq-local comment-start-skip "\\(//\\|/*\\)\\s-*")
  ;; (setq-local comment-end-skip "\\s-*\\(\\s>\\|*/\\)")
  (setq-local indent-line-function #'treeppl-indent-line)
  (setq-local font-lock-defaults '(treeppl-font-lock-keywords)))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.tppl" . treeppl-mode))
;;; treeppl-mode.el ends here
