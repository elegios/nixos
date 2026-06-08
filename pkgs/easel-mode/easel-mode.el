;;; easel-mode.el -*- lexical-binding: t -*-

(eval-when-compile
  (require 'rx))
;; Please keep these lists sorted

(defconst easel--keywords
  '(
    "if"
    "else"
    "let"
    "const"
    "use"
    "await"
    "on"
    "with"
    "once"
    "for"
    "in"
    "continue"
    "break"
    "behavior"
    "while"
    "give"
    "delete"
    "return"
    "loop"
    "match"
    "surprise"
    "repeat"

    ;; visibility
    "pub"

    ;; definition/declaration kind
    "tangible"
    "field"
    "prop" ; ?
    "symbol"
    "signal"
    "set" ; (set fn blub = param { ...)
    ))

(defconst easel--builtin-functions
  '(
    "delve"
    "this"
    ))

(defconst easel--constants
  '(
    "undefined"
    "null"
    "true"
    "false"
    ))

(defconst easel-font-lock-keywords
  (list
   `(,(regexp-opt easel--keywords 'symbols) . font-lock-keyword-face)
   `(,(regexp-opt easel--builtin-functions 'symbols) . font-lock-builtin-face)
   `(,(regexp-opt easel--constants 'symbols) . font-lock-constant-face)

   `(,(rx word-start
          (opt (group-n 3 (or "page" "game")) (+ space))
          (group-n 1
            (or "let"
                "const"
                "fn"
                "category"
                "symbol"
                "field"
                "prop"
                "signal"
                "use"
                "collect"))
          (+ space)
          (opt (+ (or alnum ":")) ".")
          (group-n 2 (+ (or alnum ":")))) (1 font-lock-keyword-face keep) (2 font-lock-variable-name-face) (3 font-lock-keyword-face keep t))

   ; timestamps
   `(,(rx "#" (repeat 4 digit) "-" (repeat 2 digit) "-" (repeat 2 digit) (opt "T" (repeat 2 digit) (repeat 0 2 ":" (repeat 2 digit)) (opt "." (repeat 1 3 digit))) word-end) . (0 font-lock-constant-face))

   ; colors
   `(,(rx "#" (or (repeat 3 hex) (repeat 4 hex) (repeat 6 hex) (repeat 8 hex)) word-end) . font-lock-constant-face)

   ; flags
   `(,(rx "0b" (one-or-more (char "01")) word-end) . font-lock-constant-face)

   ; numbers
   `(,(rx (one-or-more digit) (opt "." (one-or-more digit)) (opt (or (char "smhd") "deg" "rev") word-end)) . font-lock-constant-face)

   ; assets and vectors
   `(,(rx "@" (opt (opt "defer:") (one-or-more (or alnum (char "-._/"))))) . font-lock-constant-face)

   ; symbols
   `(,(rx "$" lower (zero-or-more (or alnum ":"))) . font-lock-constant-face)

   ; Caps-functions
   `(,(rx word-start upper (zero-or-more (or alnum ":")) word-end) . font-lock-type-face)

   ; doc-comments
   `(,(rx "///" (zero-or-more not-newline)) . (0 font-lock-doc-face t))
  )
  "List of font lock keyword specifications to use in `easel-mode'.")

(defconst easel-mode-syntax-table
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
  "Syntax table for `easel-mode'.")

(defun easel-indent-line ()
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

(define-derived-mode easel-mode prog-mode "easel"
  "Generic mode for editing MCore files."
  :syntax-table easel-mode-syntax-table
  (setq-local comment-start "//")
  (setq-local comment-end "")
  (smie-setup nil #'ignore)
  ;; (setq-local comment-start-skip "\\(//\\|/*\\)\\s-*")
  ;; (setq-local comment-end-skip "\\s-*\\(\\s>\\|*/\\)")
  (setq-local indent-line-function #'easel-indent-line)
  (setq-local font-lock-defaults '(easel-font-lock-keywords)))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.easel" . easel-mode))
;;; easel-mode.el ends here
