;;; -*- lexical-binding: t; -*-

; ==== Command mode, entering and exiting ====

(defvar ele/main-cursor nil)
(defvar ele/fake-cursors nil)

(defgroup ele nil "Ele")
(defface inactive-selection
  '((t :background "gray"))
  "Face of the selection while in insert mode")

; TODO: make the marker for the cursor follow input (I feel like it already should, but it appears not to)
(defun ele/make-overlay ()
  "Create an overlay that represents the current selection."
  (let* ((mark-even-if-inactive t)
         (mark-loc (or (mark) (point)))
         (forward (<= mark-loc (point)))
         (start (if forward mark-loc (point)))
         (end (if forward (point) mark-loc))
         (overlay (make-overlay start end (current-buffer) t t)))
    (when (use-region-p)
      (overlay-put overlay 'face 'inactive-selection))
    (mc/store-current-state-in-overlay overlay)
    ; ensure that the markers mc uses advance in the same way as the overlay itself
    ; NOTE: this uses internal stuff in multiple-cursors, gleaned from mc/store-current-state-in-overlay. Same thing for ele/pop-overlay
    (set-marker-insertion-type (overlay-get overlay 'point) t)
    (set-marker-insertion-type (overlay-get overlay 'mark) t)
    overlay))
(defun ele/pop-overlay (overlay &optional real)
  (mc/restore-state-from-overlay overlay)
  (unless real
    (mc/create-fake-cursor-at-point))
  ; NOTE: this uses internal stuff in multiple-cursors to clean up the markers a bit (not actually sure that this is necessary)
  (set-marker (overlay-get overlay 'point) nil)
  (set-marker (overlay-get overlay 'mark) nil)
  (delete-overlay overlay))

(defun ele/save-fake-cursor ()
  (interactive)
  (setq ele/fake-cursors (cons (ele/make-overlay) ele/fake-cursors)))
(defun ele/save-all-cursors ()
  (setq ele/main-cursor (ele/make-overlay))
  (setq ele/fake-cursors nil)
  (mc/execute-command-for-all-fake-cursors 'ele/save-fake-cursor)
  (setq ele/fake-cursors (reverse ele/fake-cursors)))
(defun ele/exit-command-mode ()
  (interactive)
  (ele/save-all-cursors)
  (ryo-modal-mode -1)
  (deactivate-mark))

(defun ele/enter-command-mode ()
  (interactive)
  (ryo-modal-mode 1)
  (when company-mode
    (if (not company-selection-changed)
        (company-abort)
      (advice-add 'company-call-backend :before-until 'company-tng--supress-post-completion)
      (call-interactively 'company-complete-selection)))
  (when ele/main-cursor ; TODO: there is a possibility that this messes with the screen scroll
    (mc/remove-fake-cursors)
    (dolist (ov ele/fake-cursors)
      (ele/pop-overlay ov nil))
    (setq ele/fake-cursors nil)
    (ele/pop-overlay ele/main-cursor t)
    (setq ele/main-cursor nil)))

; ==== Insertion mode ====

(defun ele/point-to-beginning-of-region ()
  (interactive)
  (goto-char (region-beginning)))
(defun ele/point-to-end-of-region ()
  (interactive)
  (goto-char (region-end)))
(defun ele/insert ()
  (interactive)
  (if (not (use-region-p))
      (ele/exit-command-mode)
    (ele/save-all-cursors)
    (mc/execute-command-for-all-cursors 'ele/point-to-beginning-of-region)
    (ryo-modal-mode -1)
    (deactivate-mark)))
(defun ele/append ()
  (interactive)
  (if (not (use-region-p))
      (progn
        (ele/exit-command-mode)
        (mc/execute-command-for-all-cursors 'forward-char))
    (ele/save-all-cursors)
    (mc/execute-command-for-all-cursors 'ele/point-to-end-of-region)
    (ryo-modal-mode -1)
    (deactivate-mark)))

(defun ele/change ()
  (interactive)
  (mc/execute-command-for-all-cursors 'delete-forward-char)
  (mc/execute-command-for-all-cursors 'ele/deactivate-mark)
  (ele/exit-command-mode))

; ==== Yank ====

; NOTE: this code is largely stolen from https://github.com/jyp/boon/blob/master/boon-main.el

(defun ele/replace-yank ()
  "Delete the region, push it to kill-ring, then yank the previous thing on the kill-ring."
  (interactive)
  (save-mark-and-excursion
    (goto-char (region-end))
    (yank))
  (kill-region (region-beginning) (region-end)))

(defun ele/need-space ()
  "Is it necessary to insert a space here to separate words or expressions?"
  (let ((back-limit (1- (point))))
  (and (not (or (eolp) (looking-at "\\s-") (looking-at "\\s)")))
       (not (or (bolp) (looking-back "\\s-" back-limit) (looking-back "\\s(" back-limit)))
       (or (and (looking-back "\\sw\\|\\s_\\|\\s.\\|\\s)" back-limit) (looking-at "\\sw\\|\\s_\\|\\s("))))))

(defun ele/fix-a-space ()
  "Fix the text to have the right amount of spacing at the point.
Return nil if no changes are made, t otherwise."
  (interactive)
  (let ((back-limit (1- (point))))
  (cond ((bolp) nil) ;; inserted at least one full line.
        ((looking-at " ")
         (when (or (bolp) (looking-back "\\s-\\|\\s(" back-limit))
           (delete-char 1)
           t))
        ((looking-back " " back-limit)
         (when (or (eolp) (looking-at "\\s-\\|\\s)\\|\\s."))
           (delete-char -1)
           t))
        ((ele/need-space)
         (insert " ")
         t)
        (t nil))))

(defun ele/yank-fix-spaces ()
  "Yank, replacing the region if it is active.
Fix the surroundings so that they become nicely spaced.
Return nil if no changes are made."
  (interactive)
  (let ((fix-here (ele/fix-a-space))
        (fix-there (save-excursion
                     (goto-char (mark))
                     (ele/fix-a-space))))
    ;; done this way because 'or' is lazy
    (or fix-here fix-there)))

(defhydra ele/yank-hydra (:columns 4)
  "A hydra for yanking niceties and handling of the kill ring"
  ("p" ele/yank-fix-spaces "Fix spaces" :exit t)
  ("h" (yank-pop -1) "Previous kill")
  ("l" (yank-pop 1) "Next kill")
  ("q" nil "Cancel"))

(defun ele/yank ()
  "Yank, replacing the region if it is active.
Then enter a hydra for moving through the kill ring or fixing
the surrounding spaces."
  (interactive)
  (when (use-region-p)
    (delete-region (region-beginning) (region-end)))
  (yank)
  (ele/yank-hydra/body))

; ==== Selection ====

(defun ele/exchange-point-and-mark ()
  (interactive)
  (if (use-region-p)
      (exchange-point-and-mark)
    (push-mark (point))
    (activate-mark)))

(defun ele/keyboard-quit ()
  "Deactivate mark if there are any active, otherwise exit multiple-cursors-mode."
  (interactive)
  (if (not (region-active-p))
      (multiple-cursors-mode 0)
    (mc/execute-command-for-all-cursors 'ele/deactivate-mark)))

(defun ele/expand-line ()
  (interactive)
  (let* ((mark-loc (if (use-region-p) (mark) (point)))
         (forward (<= mark-loc (point))))
    (push-mark mark-loc)
    (when forward
      (exchange-point-and-mark))
    (forward-line 0)
    (exchange-point-and-mark)
    (unless (and (bolp)
                 (/= (point) (mark)))
      (forward-line 1))
    (unless forward
        (exchange-point-and-mark))))

(defun ele/mark-isearch-other-end ()
  (interactive)
  (push-mark isearch-other-end)
  (activate-mark))

; ==== C-c replacement ====

; Stolen from boon
(defun ele/god-control-swap (event)
  "Swap the control 'bit' in EVENT, unless C-c <event> is a prefix reserved for modes."
  (interactive (list (read-key)))
  (cond
   ((memq event '(9 13 ?{ ?} ?[ ?] ?$ ?< ?> ?: ?\; ?/ ?? ?. ?, ?' ?\")) event)
   ((<= event 27) (+ 96 event))
   ((not (eq 0 (logand (lsh 1 26) event))) (logxor (lsh 1 26) event))
   (t (list 'control event))))

(defun ele/c-god (arg)
  "Input a key sequence, prepending C- to keys unless keys are
already reserved for modes, and run the command bound to that
sequence."
  (interactive "P")
  (let ((keys '((control c)))
        (binding (key-binding (kbd "C-c")))
        (key-vector (kbd "C-c"))
        (prompt "C-c-"))
    (while (and binding
                (or (eq binding 'mode-specific-command-prefix)
                    ;; if using universal prefix, the above will happen.
                    (not (symbolp binding))))
      (let ((key (read-key (format "%s" prompt))))
        (if (eq key ?h) (describe-bindings key-vector) ;; h -> show help
          (push (ele/god-control-swap key) keys)
          (setq key-vector (vconcat (reverse keys)))
          (setq prompt (key-description key-vector))
          (setq binding (key-binding key-vector)))))
    (cond
     ((not binding) (error "No command bound to %s" prompt))
     ((commandp binding)
      (let ((current-prefix-arg arg)) (call-interactively binding)))
     (t (error "Key not bound to a command: %s" binding)))))

; ==== Macros ====

(defun ele/define-or-end-macro ()
  (interactive)
  (if defining-kbd-macro
      (kmacro-end-macro 1)
    (kmacro-start-macro nil)))

; ==== Themes ====

(defvar *ele-theme-dark* 'solarized-dark)
(defvar *ele-theme-light* 'solarized-light)
(defvar *ele-current-theme* *ele-theme-dark*)

;; disable other themes before loading new one
(defadvice load-theme (before theme-dont-propagate activate)
  "Disable theme before loading new one."
  (mapc #'disable-theme custom-enabled-themes))

(defun ele/next-theme (theme)
  (if (eq theme 'default)
      (disable-theme *ele-current-theme*)
    (progn
      (load-theme theme t)))
  (setq *ele-current-theme* theme))

(defun ele/toggle-theme ()
  (interactive)
  (cond ((eq *ele-current-theme* *ele-theme-dark*) (ele/next-theme *ele-theme-light*))
        ((eq *ele-current-theme* *ele-theme-light*) (ele/next-theme *ele-theme-dark*))))

; ==== Misc ====

(defun ele/edit-emacs-config ()
  (interactive)
  (cond
   ((file-exists-p "~/.config/nixos/dotfiles/emacs/init.el")
    (find-file "~/.config/nixos/dotfiles/emacs/init.el"))
   (t (find-file (locate-user-emacs-file "init.el")))))

(defvar-local ele/bookmark nil)
(defun ele/set-bookmark ()
  (interactive)
  (if ele/bookmark
      (set-marker ele/bookmark (point))
    (setq ele/bookmark (copy-marker (point)))))
(defun ele/goto-bookmark ()
  (interactive)
  (if ele/bookmark
      (goto-char (marker-position ele/bookmark))
    (message "No bookmark currently set in this buffer")))

(defun ele/wrap-region-in-pair ()
  (interactive)
  (let* ((start (copy-marker (region-beginning) t))
         (end (copy-marker (region-end) nil))
         (forward (= (point) end)))
    (call-interactively 'insert-pair)
    (goto-char (if forward end start))
    (set-mark (if forward start end))
    (setq deactivate-mark nil)))

(defun ele/deactivate-mark ()
  (interactive)
  (deactivate-mark))

(defun ele/forward-word ()
  (interactive)
  (let ((curr (point))
        (foreword (save-mark-and-excursion
                    (forward-word 1)
                    (point)))
        (eol (save-mark-and-excursion
               (end-of-visual-line)
               (point))))
    (goto-char
     (if (= curr eol)
         foreword
       (min foreword eol)))))

(defun ele/backward-word ()
  (interactive)
  (let ((curr (point))
        (backword (save-mark-and-excursion
                    (forward-word -1)
                    (point)))
        (bol (save-mark-and-excursion
               (beginning-of-visual-line)
               (point))))
    (goto-char
     (if (= curr bol)
         backword
       (max backword bol)))))

(defun ele/backward-kill-word ()
  (interactive)
  (if (bolp)
      (backward-delete-char 1)
    (let ((end (point))
          (start (ele/backward-word)))
      (kill-region start end))))

(defun ele/dedup-cursors ()
  (interactive)) ; TODO: merge cursors whose regions overlap

(defun ele/join-line () ; TODO: handle region appropriately
  (interactive)
  (if (region-active-p)
      (save-mark-and-excursion
        (if (< (point) (mark))
            (exchange-point-and-mark))
        (if (bolp)
            (backward-char 1))
        (exchange-point-and-mark)
        (while (search-forward "\n" (region-end) t)
          (join-line))
        (setq deactivate-mark nil))
    (join-line t)))

(defun ele/save-all ()
  (interactive)
  (save-some-buffers t))

(defun ele/activate-mark ()
  (interactive)
  (activate-mark))

; TODO: this probably always uses spaces instead of following the current file setting
(defun ele/indent ()
  (interactive)
  (save-mark-and-excursion
   (ele/expand-line)
   (indent-rigidly-right-to-tab-stop (region-beginning) (region-end)))
  (setq deactivate-mark nil))

(defun ele/dedent ()
  (interactive)
  (save-mark-and-excursion
   (ele/expand-line)
   (indent-rigidly-left-to-tab-stop (region-beginning) (region-end)))
  (setq deactivate-mark nil))

(defun ele/goto-line ()
  "Show line numbers temporarily, while prompting for the line number input"
  (interactive)
  (let ((lm (if (bound-and-true-p display-line-numbers-mode) 1 -1)))
    (unwind-protect
        (progn
          (display-line-numbers-mode 1)
          (goto-line (read-number "Goto line: ")))
      (display-line-numbers-mode lm))))

(defun ele/avy-goto-grid ()
  "Goto a position on screen using avy pointing at a grid of
positions, as opposed to something related to the contents of
each line."
  (interactive)
  (avy-jump "[^\n]\\{10\\}" :beg (window-start) :end (window-end (selected-window) t)))

(defun ele/avy-goto-char (char &optional arg)
  "Jump to the currently visible CHAR.
The window scope is determined by `avy-all-windows' (ARG negates it)."
  (interactive (list (read-char "char: " t)
                     current-prefix-arg))
  (setq ele/avy-start (string (avy--key-to-char char)))
  (setq avy-action nil)
  (avy-jump
   (if (= 13 char)
       "\n"
     (regexp-quote (string char)))
   :window-flip arg))

(defun ele/avy-action-embark (pt)
  (unwind-protect
      (save-excursion
        (goto-char pt)
        (embark-act))
    (select-window
     (cdr (ring-ref avy-ring 0))))
  t)

(defun ele/avy-embark-to-char (char)
  "Use 'embark-act' on a currently visible CHAR."
  (interactive (list (read-char "char: " t)))
  (setq ele/avy-start (string (avy--key-to-char char)))
  (setq avy-action 'ele/avy-action-embark)
  (avy-jump
   (if (= 13 char)
       "\n"
     (regexp-quote (string char)))))


; TODO: ensure these (open line) interact nicely with selections
(defun ele/open-line-below ()
  (interactive)
  (end-of-line)
  (newline)
  (indent-for-tab-command))

(defun ele/open-line-above ()
  (interactive)
  (beginning-of-line)
  (newline)
  (forward-line -1)
  (indent-for-tab-command))

(defun ele/shell-command (command)
  (interactive (list (read-shell-command "Enter shell command: ")))
  (let ((shell-file-name (executable-find "fish")))
    (if (use-region-p)
        (shell-command-on-region (region-beginning) (region-end) command t t)
      (shell-command command t)))
  (setq deactivate-mark nil))

(defun ele/comment ()
  (interactive)
  (save-mark-and-excursion
    (when (use-region-p)
      (if (< (point) (mark))
          (exchange-point-and-mark))
      (if (bolp)
          (backward-char 1)))
    (comment-line 1))
  (setq deactivate-mark nil))

(defun ele/insert-todo-like (kind)
  (push-mark (point))
  (insert kind "(vipa, " (format-time-string "%Y-%m-%d") "): ")
  (comment-region (mark) (point))
  (ele/insert))

(defun ele/insert-todo ()
  (interactive)
  (ele/insert-todo-like "TODO"))

(defun ele/insert-note ()
  (interactive)
  (ele/insert-todo-like "NOTE"))

(defun ele/insert-opt ()
  (interactive)
  (ele/insert-todo-like "OPT"))

(defun ele/delete (arg)
  (interactive "p")
  (if (use-region-p)
      (kill-region (region-beginning) (region-end) 'region)
    (delete-char arg t)))

(defun ele/delete-no-kill (arg)
  (interactive "p")
  (if (use-region-p)
      (delete-region (region-beginning) (region-end))
    (delete-char arg nil)))

(defun ele/switch-window ()
  (interactive)
  (select-window
    (if (= 1 (count-windows))
        (split-window-right)
      (next-window))))

(defun ele/toggle-vertical-split ()
  (interactive)
  (if (> (window-height) (/ (frame-height) 2))
      (split-window-below)
    (let ((other (window-in-direction 'above nil nil nil t nil)))
      (if (window-minibuffer-p other)
          (message "Found only the minibuffer, won't remove that")
        (delete-window other)))))

(defun ele/increment-number-decimal (&optional arg)
  "Increment the number forward from point by 'arg'."
  (interactive "p*")
  (save-excursion
    (save-match-data
      (let (inc-by field-width answer)
        (setq inc-by (if arg arg 1))
        (skip-chars-backward "0123456789")
        (when (re-search-forward "[0-9]+" nil t)
          (setq field-width (- (match-end 0) (match-beginning 0)))
          (setq answer (+ (string-to-number (match-string 0) 10) inc-by))
          (when (< answer 0)
            (setq answer (+ (expt 10 field-width) answer)))
          (replace-match (format (concat "%0" (int-to-string field-width) "d")
                                 answer)))))))

(defun ele/toggle-case ()
  "Toggle the case of the region if present, otherwise at point."
  (interactive)
  (let ((start (if (region-active-p) (region-beginning) (point)))
        (end (if (region-active-p) (region-end) (+ 1 (point))))
        (case-fold-search nil))
    (save-mark-and-excursion
      (goto-char start)
      (while (re-search-forward "\\([[:lower:]]+\\)\\|\\([[:upper:]]+\\)" end t)
        (if (string-match-p "[[:lower:]]" (match-string 0) 0)
            (upcase-region (match-beginning 0) (match-end 0))
          (downcase-region (match-beginning 0) (match-end 0)))))))

(defun ele/shell-and-update-output (b e)
  "Run current line (or region if active) as shell code and insert/update output.

B is the initial point of the command to run, E is the end point."
  (interactive
   (if (region-active-p)
       (list (region-beginning) (region-end))
     (list (line-beginning-position)
           (line-end-position))))
  (save-excursion
    ;; delete old output
    (delete-region
     (progn (forward-line) (point))
     (progn (while (get-text-property (point) '$$)
              (forward-line))
            (point)))

    (unless (bolp) (insert "\n"))
    (let* ((command (buffer-substring-no-properties b e))
           (output (with-temp-buffer
                     (let ((shell-file-name (executable-find "fish")))
                       (shell-command command t nil)
                       (buffer-string))))
           (start (point)))
      (insert (propertize output '$$ t 'rear-nonsticky t))
      (pulse-momentary-highlight-region start (point)))))

(defvar ele/grid-columns '(10 28 50 72))
(defvar ele/grid-hori-radius 30) ; Columns
(defvar ele/grid-vert-radius ) ; Fraction of window height
(defvar ele/grid-column-keys '(?a ?o ?e ?u))
(defvar ele/grid-row-keys '(?h ?t ?n ?s))

(defun ele/for-lines-in-rect (lstart lend cstart cend f)
  ""
  (save-excursion
    (let* ((startpoint (progn (move-to-window-line lstart) (point)))
           (endpoint (progn (move-to-window-line lend) (point))))
      (goto-char startpoint)
      (while (< (point) endpoint)
        (let ((start (progn (move-to-column cstart) (point)))
              (end (progn (move-to-column cend) (point))))
          (goto-char start)
          (funcall f start end)
          (vertical-motion 1))))))

(defun ele/candidates-in-rect (re lstart lend cstart cend)
  "Produces a list of candidates as expected by avy.  The candidates
are only those fully contained within the given rectangle."
  (let ((wnd (selected-window))
        (candidates nil))
    (ele/for-lines-in-rect
     lstart lend cstart cend
     (lambda (_ end)
       (while (re-search-forward re end t)
         (push (cons (cons (match-beginning 0) (match-end 0)) wnd) candidates))))
    (nreverse candidates)))

(defvar ele/grid-face 'highlight)

;; TODO(vipa, 2023-11-27): This tries to set up line numbering
;; relative to the visual beginning of the window, plus major-tick
;; highlights at 4 evenly spaced points in the buffer. Unfortunately
;; the latter doesn't seem to update nicely in all cases.
(when nil
  (add-to-list
   'window-scroll-functions
   (lambda (wnd start)
     (when (or (eq wnd (selected-window))
               (not (eq (window-buffer wnd) (window-buffer (selected-window)))))
       (with-selected-window wnd
         (let* ((lines (window-body-height wnd))
                (tick-length (ceiling (/ lines 4))))
           (setq display-line-numbers-major-tick tick-length)
           (setq display-line-numbers-offset
                 (- (1- (line-number-at-pos start)))))))))
  (setq display-line-numbers-width 2)
  (setq window-scroll-functions nil)
  (setq display-line-numbers-offset 0))

(defun ele/igoto-around-point (vcol vrow)
  "."
  )

(defun ele/show-grid ()
  "."
  (interactive)
  (seq-do-indexed
   (lambda (rkey row)
     (cl-mapc
      (lambda (ckey col next-col)
        (key-chord-define
         ryo-modal-mode-map
         (vector rkey ckey)
         (lambda ()
           (interactive)
           (let* ((lines (window-body-height))
                  (chunk-height (/ lines (length ele/grid-row-keys)))
                  (lstart (* row chunk-height))
                  (lend (* (1+ row) chunk-height))
                  (cstart col)
                  (cend next-col)
                  (overlays nil))
             (ele/for-lines-in-rect
              lstart lend cstart cend
              (lambda (start end)
                (when (/= start end)
                  (let ((ov (make-overlay start end)))
                    (overlay-put ov 'face ele/grid-face)
                    (push ov overlays)))))
             (unwind-protect
                 (avy-process
                  (ele/candidates-in-rect
                   (regexp-quote (string (read-char "char: " t)))
                   lstart lend cstart cend))
               (seq-do (symbol-function 'delete-overlay) overlays))))))
      ele/grid-column-keys
      ele/grid-columns
      (cdr ele/grid-columns)))
   ele/grid-row-keys)
  (column-marker-create ele/grid-jump-1 ele/grid-face)
  (column-marker-create ele/grid-jump-2 ele/grid-face)
  (column-marker-create ele/grid-jump-3 ele/grid-face)
  (ele/grid-jump-1 (nth 1 ele/grid-columns))
  (ele/grid-jump-2 (nth 2 ele/grid-columns))
  (ele/grid-jump-3 (nth 3 ele/grid-columns)))

(provide 'ele)


;; TODO(vipa, 2023-05-22): do something proper with this

;; (defun ele/visible-tokens ()
;;   "Find all visible tokens."
;;   (let ((tokens nil)
;;         (prev nil))
;;     (save-excursion
;;       (save-restriction
;;         (goto-char (window-start))
;;         (end-of-visual-line (/ (window-body-height) 2))
;;         (narrow-to-region (window-start) (point))
;;         (setq prev (goto-char (point-min)))
;;         (while (< (point) (point-max))
;;           (forward-same-syntax)
;;           (unless (string-match-p "\\`\\s-*$" (buffer-substring-no-properties prev (point)))
;;             (push (cons prev (point)) tokens))
;;           (setq prev (point)))))
;;     tokens))

;; (defun ele/min-repr (reprs region)
;;   "REPRS REGION."
;;   (let ((bestCost 1000)
;;         (bestRepr nil)
;;         (bestPos nil))
;;     (dotimes (i (- (cdr region) (car region)))
;;       (let* ((pos (+ (car region) i))
;;              (repr (char-after pos))
;;              (cost (length (gethash repr reprs nil))))
;;         (when (< cost bestCost)
;;           (setq bestCost cost)
;;           (setq bestRepr repr)
;;           (setq bestPos pos))))
;;     (cons bestRepr bestPos)))

;; (defvar ele/hat-map (make-hash-table))

;; (defun ele/greedy-region-representatives (reprs regions)
;;   "REPRS REGIONS."
;;   (clrhash reprs)
;;   (dolist (r regions)
;;     (let* ((repr (ele/min-repr reprs r))
;;            (pos (cdr repr))
;;            (repr (car repr))
;;            (prev (gethash repr reprs nil)))
;;       (puthash repr (cons (cons pos r) prev) reprs))))

;; (ele/greedy-region-representatives ele/hat-map (ele/visible-tokens))

;; (defvar ele/hats nil)
;; (defun ele/update-hats ()
;;   "."
;;   (dolist (h ele/hats)
;;     (delete-overlay h))
;;   (setq ele/hats nil)
;;   (ele/greedy-region-representatives ele/hat-map (ele/visible-tokens))
;;   (let ((marks nil))
;;     (maphash
;;      (lambda (repr pos-and-regions)
;;        (let ((idx 0)
;;              (len (length pos-and-regions)))
;;          (dolist (r pos-and-regions)
;;            (push (cons (car r) (cons idx len)) marks)
;;            (setq idx (+ idx 1)))))
;;      ele/hat-map)
;;     (ele/show-hat-lines (sort marks (lambda (a b) (< (car a) (car b)))))))

;; (defun ele/show-hat-lines (marks)
;;   (while marks
;;     (let* ((p (car (car marks)))
;;            (start (save-excursion (goto-char p) (beginning-of-visual-line) (point)))
;;            (end (save-excursion (goto-char p) (end-of-visual-line) (point))))
;;       (setq marks (ele/show-hat-line start end marks)))))

;; (defun ele/show-idx (idx)
;;   (avy-subdiv (
;;   (nth (mod idx 5) '("↓" "." "," ":" ";")))

;; (defun ele/show-hat-line (start end marks)
;;   (let ((str ""))
;;     (while (and marks (< (car (car marks)) end))
;;       (let* ((pos (car (car marks)))
;;              (idx (cdr (car marks)))
;;              (padding (make-string (- pos start (length str)) ?\s)))
;;         (setq str (concat str padding (ele/show-idx idx)))
;;         (setq marks (cdr marks))))
;;     (let ((o (make-overlay start start)))
;;       (overlay-put o 'before-string str)
;;       (overlay-put o 'after-string "\n")
;;       (overlay-put o 'priority 100)
;;       (push o ele/hats))
;;     marks))

;; TODO(vipa, 2023-05-25): did some more work on trying to use just
;; overlays, the resulting code is below. It is not really readable,
;; so it probably has to count as a failure.

;; (defun ele/visible-tokens ()
;;   "Find all visible tokens."
;;   (let ((tokens nil)
;;         (prev nil))
;;     (save-excursion
;;       (save-restriction
;;         (goto-char (window-start))
;;         (end-of-visual-line (window-body-height))
;;         (narrow-to-region (window-start) (point))
;;         (setq prev (goto-char (point-min)))
;;         (while (< (point) (point-max))
;;           (forward-same-syntax)
;;           (unless (string-match-p "\\`\\s-*$" (buffer-substring-no-properties prev (point)))
;;             (push (cons prev (point)) tokens))
;;           (setq prev (point)))))
;;     tokens))

;; (defun ele/min-repr (reprs region)
;;   "REPRS REGION."
;;   (let ((bestCost 1000)
;;         (bestRepr nil)
;;         (bestPos nil))
;;     (dotimes (i (- (cdr region) (car region)))
;;       (let* ((pos (+ (car region) i))
;;              (repr (char-after pos))
;;              (cost (length (gethash repr reprs nil))))
;;         (when (< cost bestCost)
;;           (setq bestCost cost)
;;           (setq bestRepr repr)
;;           (setq bestPos pos))))
;;     (cons bestRepr bestPos)))

;; (defun ele/greedy-region-representatives (reprs regions)
;;   "REPRS REGIONS."
;;   (clrhash reprs)
;;   (dolist (r regions)
;;     (let* ((repr (ele/min-repr reprs r))
;;            (pos (cdr repr))
;;            (repr (car repr))
;;            (prev (gethash repr reprs nil)))
;;       (puthash repr (cons (cons pos r) prev) reprs))))

;; (defcustom ele/hat-default-color
;;   (face-foreground 'font-lock-comment-face)
;;   "Color to use when there's only a single hat, so no color is needed"
;;   :group 'ele
;;   :type '(color))

;; (defcustom ele/hat-colors
;;   (list
;;    (cons ?r (alist-get 'red solarized-dark-color-palette-alist))
;;    (cons ?g (alist-get 'green solarized-dark-color-palette-alist))
;;    (cons ?b (alist-get 'blue solarized-dark-color-palette-alist))
;;    (cons ?y (alist-get 'yellow solarized-dark-color-palette-alist)))
;;   "List of colors to use for hats when there are many marks"
;;   :group 'ele
;;   :type '(list color))

;; (defvar-local ele/hat-map (make-hash-table))
;; (defvar-local ele/hats nil)

;; (defun ele/clear-hats ()
;;   (dolist (h ele/hats)
;;     (delete-overlay h))
;;   (setq ele/hats nil))

;; (defun ele/update-hats ()
;;   "."
;;   (ele/clear-hats)
;;   (ele/greedy-region-representatives ele/hat-map (ele/visible-tokens))
;;   (ad-with-originals (avy-tree)
;;     (maphash
;;      (lambda (repr pos-and-regions)
;;        (if (length< pos-and-regions 2)
;;            (ele/customize-hat '() (car pos-and-regions))
;;          (avy-traverse
;;           (avy-tree pos-and-regions ele/hat-colors)
;;           'ele/customize-hat)))
;;      ele/hat-map)))

;; (defun ele/customize-hat (keys pos-and-region)
;;   (let* ((pos (car pos-and-region))
;;          (props '(:overline :underline))
;;          (ov (make-overlay pos (1+ pos))))
;;     (push ov ele/hats)
;;     (overlay-put ov 'priority 100)
;;     (overlay-put ov 'face
;;                  (append
;;                   (list ':box ele/hat-default-color)
;;                   (if (null keys)
;;                       (list ':overline ele/hat-default-color)
;;                     (flatten-list (-zip props (seq-map 'cdr (reverse keys)))))))))

;; TODO(vipa, 2023-05-25): Thoughts on possible ways forward:
;; - try to hack emacs to add a new 'display type
;; - make a separate utility for displaying "overlays" on
;;   the line above the actual text, then use that for actual
;;   hats.
;;   - This could possibly use a space 'display thing, it can say
;;     what to align to, even on a pixel scale, so it might be possible
;;     to have a smaller line and still align properly.
;;   - This would always show an extra line above each line, so it
;;     fixes the strangeness where I don't quite know which lines to
;;     adorn with hats.
;; - think of some other addressing mode, e.g., words of length at least
;;   2 seem reasonable to target with something like the current scheme,
;;   but symbols (parens and the like) seem harder to do in that way.

;; ;; (ele/update-hats)
