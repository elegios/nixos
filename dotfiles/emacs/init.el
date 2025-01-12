; ==== Misc small settings ====

(setq inhibit-splash-screen t)
(when (and (fboundp 'menu-bar-mode) (not (eq system-type 'darwin))) (menu-bar-mode -1))
(when (fboundp 'tool-bar-mode) (tool-bar-mode -1))
(when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))
(add-to-list 'default-frame-alist '(fullscreen . maximized))
(global-auto-revert-mode t)
(setq column-number-mode t)
(setq-default indent-tabs-mode nil)
(setq-default tab-width 2)
(setq-default show-trailing-whitespace t)
(setq-default electric-indent-inhibit t)
(setq scroll-conservatively 9000)
(setq scroll-margin 5)
(setq scroll-preserve-screen-position t)
(setq backup-directory-alist
      `((".*" . ,(expand-file-name
		             (concat user-emacs-directory "backups")))))
(setq vc-make-backup-files t)
(setq mouse-wheel-progressive-speed nil) ;; don't accelerate scrolling
(setq mouse-wheel-follow-mouse 't) ;; scroll window under mouse
(setq mouse-wheel-scroll-amount '(1 ((shift) . 1))) ;; one line at a time
(add-hook 'prog-mode-hook
          (lambda ()
            (add-to-list 'write-file-functions 'delete-trailing-whitespace)
            (setq truncate-lines t)))
(setq-default major-mode 'indented-text-mode)

(setq show-paren-delay 0)
(show-paren-mode 1)
(global-unset-key (kbd "C-z"))
(pixel-scroll-precision-mode)


; ==== Setup package management ====

(require 'package)
(add-to-list 'package-archives '("melpa" . "http://melpa.org/packages/"))
;; TODO(vipa, 2023-09-08): This is probably needed for the first run
;; of emacs, to ensure we can install packages
;; (package-initialize t)
;; (if package-archive-contents
;;   (package-refresh-contents t)
;;   (package-refresh-contents nil))

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))


; ==== Setup use-package ====

(eval-when-compile
  (when (not (package-installed-p 'use-package))
    (package-install 'use-package))
  (require 'use-package))
(setq use-package-always-ensure t)
(use-package use-package-chords
  :demand t
  :config
  (setq key-chord-safety-interval-backward 0)
  (setq key-chord-safety-interval-forward 0)
  (key-chord-mode 1))


; ==== Get exec-path and stuff from shell, then switch to bash to be posix-compliant ====

;; (when (memq system-type '(darwin gnu/linux))
;;   (use-package exec-path-from-shell
;;     :config
;;     (exec-path-from-shell-initialize)))

(if (executable-find "bash")
    (setq shell-file-name (executable-find "bash"))
  (when (file-exists-p "d:/Program Files (x86)/Git/bin/bash.exe")
    (setq shell-file-name "d:/Program Files (x86)/Git/bin/bash.exe"))
  (when (file-exists-p "c:/Program Files/Git/usr/bin/bash.exe")
    (setq shell-file-name "c:/Program Files/Git/usr/bin/bash.exe")))


; ==== Core setup ====

(use-package diminish
  :demand t)

(use-package solarized-theme
  :config
  (load-theme 'solarized-dark 'no-confirm))

(use-package expand-region
  :commands (er/expand-region er/contract-region
             er/mark-inside-quotes er/mark-outside-quotes
             er/mark-inside-pairs er/mark-outside-pairs)
  :config
  (setq expand-region-contract-fast-key ":"))

(use-package multiple-cursors
  :commands
  (mc/mark-next-lines mc/mark-previous-lines mc/keyboard-quit
   mc/store-current-state-in-overlay mc/restore-state-from-overlay
   mc/execute-command-for-all-cursors multiple-cursors-mode
   mc/execute-command-for-all-fake-cursors)
  :config
  (define-key mc/keymap (kbd "<return>") nil)
  (add-to-list 'mc/cursor-specific-vars 'corral--virtual-point))


(use-package which-key
  :diminish which-key-mode
  :config
  (which-key-mode))

(use-package company
  :diminish company-mode
  :demand t
  :bind
  (:map company-active-map
   ("C-n" . company-select-next)
   ("<down>" . company-select-next)
   ("C-p" . company-select-previous)
   ("<up>" . company-select-previous))
  :chords
  (:map company-active-map
   ("jk" . ele/enter-command-mode))

  :config
  (setq company-idle-delay 0)
  (setq company-selection-default nil)
  (setq company-require-match nil)
  (setq company-minimum-prefix-length 2)
  (setq company-frontends '(company-tng-frontend
                            company-pseudo-tooltip-frontend
                            company-echo-metadata-frontend))
  (define-key company-active-map (kbd "RET") nil)
  (define-key company-active-map [return] nil)
  (global-company-mode))

;; (use-package lsp-mode
;;   :commands lsp
;;   :bind ("C-c C-a" . lsp-execute-code-action))

;; (use-package lsp-ui
;;   :after lsp-mode
;;   :custom
;;   (lsp-ui-doc-enable nil))

(use-package eldoc
  :diminish eldoc-mode
  :config
  (setq eldoc-echo-area-use-multiline-p nil)
  (setq eldoc-echo-area-prefer-doc-buffer t))

(use-package eglot
  :hook (latex-mode . eglot-ensure)
  :config
  (fset #'jsonrpc--log-event #'ignore))

(use-package dtrt-indent
  :diminish dtrt-indent-mode
  :config
  (setq-default dtrt-indent-mode t))

(use-package hydra)

(use-package flycheck
  :init
  (global-flycheck-mode))

(use-package flycheck-eglot
  :ensure t
  :after (flycheck eglot)
  :config
  (global-flycheck-eglot-mode 1))

(use-package corral
  :commands
  (corral-parentheses-backward corral-parentheses-forward
   corral-brackets-backward corral-brackets-forward
   corral-braces-backward corral-braces-forward
   corral-single-quotes-backward corral-single-quotes-forward
   corral-double-quotes-backward corral-double-quotes-forward
   corral-backquote-backward corral-backquote-forward)
  :config
  (setq corral-preserve-point t))

(use-package avy
  :commands
  (avy-goto-char avy-pop-mark avy--key-to-char)
  :config
  (setq avy-keys '(?a ?o ?e ?u ?h ?t ?n ?s))
  (setq avy-dispatch-alist '())

  ;; TODO(vipa, 2022-10-09): Create PRs for push and pop?
  (defadvice avy-push-mark (around ele/avy-push-mark activate)
    "Store a marker instead of an int"
    (let ((inhibit-message t))
      (when (= (ring-size avy-ring) (ring-length avy-ring))
        (set-marker (car (ring-remove avy-ring nil)) nil))
      (ring-insert avy-ring
                   (cons (copy-marker (point-marker)) (selected-window)))
      (unless (region-active-p)
        (push-mark))))

  (defadvice avy-pop-mark (around ele/avy-pop-mark activate)
    (let (res)
      (condition-case nil
          (progn
            (while (not (window-live-p
                         (cdr (setq res (ring-remove avy-ring 0))))))
            (let* ((window (cdr res))
                   (frame (window-frame window)))
              (when (and (frame-live-p frame)
                         (not (eq frame (selected-frame))))
                (select-frame-set-input-focus frame))
              (select-window window)
              (goto-char (car res))
              (set-marker (car res) nil)))
        (error
         (set-mark-command 4))))))

(use-package smartparens-config
  :ensure smartparens
  :commands
  (sp-backward-slurp-sexp sp-backward-barf-sexp sp-forward-barf-sexp
   sp-forward-slurp-sexp sp-rewrap-sexp sp-splice-sexp sp-raise-sexp
   sp-split-sexp sp-join-sexp)
  :diminish smartparens-mode)

(use-package projectile
  :commands (projectile-find-file)
  :config
  (projectile-mode 1)
  (add-to-list 'projectile-globally-ignored-directories "^\\.tup$")
  (if (equal projectile-jj-command "jj files --no-pager . | tr '\\n' '\\0'")
      (setq projectile-jj-command "jj file list --no-pager . | tr '\\n' '\\0'")
    (message "projectile-jj-command seems to have been updated, see if this part can be removed from 'init.el'"))
  (when (eq system-type 'windows-nt)
    (setq projectile-indexing-method 'alien)))

(use-package goto-last-change
  :commands (goto-last-change))

(use-package visual-regexp-steroids
  :commands (vr/mc-mark))

(use-package ido
  :bind
  (:map ido-common-completion-map
        ("SPC" . ido-restrict-to-matches)
        ("C-SPC" . ido-complete-space))
  :config
  (ido-mode t)
  (setq ido-enable-flex-matching t)
  (setq ido-case-fold t)
  (setq ido-auto-merge-work-directories-length -1))

(use-package ido-vertical-mode
  :after ido
  :config
  (setq ido-vertical-define-keys 'C-n-C-p-up-and-down)
  (ido-vertical-mode 1))

(use-package smex
  :after ido
  :commands (smex))

(use-package ido-completing-read+
  :after ido
  :config
  (ido-ubiquitous-mode 1))

;; TODO: setup good folding, that doesn't break all my shortcuts
;; (use-package outshine)
;; Oscar had a short function that might be a good fit?

(use-package bm
  :commands (bm-next bm-toggle)
  :config
  (setq bm-highlight-style 'bm-highlight-only-fringe))

(use-package ele
  :ensure nil)

(use-package sam
  :commands (sam-eval-last-command)
  :ensure nil
  :config
  (setq sam-emacs-style-regexps t))

(use-package selected
  :demand t
  :diminish selected-minor-mode
  :after (ele)
  :bind
  (:map selected-keymap
        ("TAB" . indent-region)
        ("s" . vr/mc-mark)
        ("P" . ele/replace-yank)
        ("(" . ele/wrap-region-in-pair)
        ("[" . ele/wrap-region-in-pair)
        ("{" . ele/wrap-region-in-pair)
        ("\"" . ele/wrap-region-in-pair)))

(use-package atomic-chrome
  :commands (atomic-chrome-start-server))

; The setup here is for basic, available anywhere stuff
(use-package ryo-modal
  :demand t
  :diminish ryo-modal-mode
  :after (ele company)
  :commands (ryo-modal)
  :chords (("jk" . ele/enter-command-mode))

  :config
  (add-to-list 'emulation-mode-map-alists
               `((selected-region-active-mode . ,selected-keymap)
                 (ryo-modal-mode . ,ryo-modal-mode-map)))
  (add-hook 'prog-mode-hook 'ele/enter-command-mode)
  (add-hook 'text-mode-hook 'ele/enter-command-mode)
  (add-hook 'ryo-modal-mode-hook
            (lambda ()
              (if ryo-modal-mode
                  (selected-minor-mode 1)
                (selected-minor-mode -1))))
  ; disable insertion in modal mode
  (suppress-keymap ryo-modal-mode-map)

  (setq ryo-modal-cursor-color "goldenrod")

  (define-key global-map [remap backward-kill-word] 'ele/backward-kill-word)
  (define-key global-map (kbd "C-S-g") 'ele/enter-command-mode)

  ; Make text size change in all buffers at once
  (defadvice text-scale-increase (around all-buffers (arg) activate)
    (dolist (buffer (buffer-list))
      (with-current-buffer buffer
        ad-do-it)))
  (defadvice text-scale-decrease (around all-buffers (arg) activate)
    (dolist (buffer (buffer-list))
      (with-current-buffer buffer
        ad-do-it)))

  ; TODO: ' for transpose selections
  ; TODO: ~ for caps case
  ; TODO: indentation stuff is still wrong, it doesn't default correctly, and <> do not indent correctly
  ; TODO: maybe make the bookmark save all cursors and regions, instead of just the current point?
  (ryo-modal-keys
    ; movement
    ("j" next-line)
    ("J" mc/mark-next-lines)
    ("k" previous-line)
    ("K" mc/mark-previous-lines)

    ("b" ele/backward-word)
    ("e" ele/forward-word)
    ("h" backward-char)
    ("l" forward-char)

    ("/" isearch-forward)
    ("n" isearch-repeat-forward)
    ("M-n" isearch-repeat-backward)
    ("N" ele/mark-isearch-other-end)

    ("g"
     (("h" beginning-of-line)
      ("l" end-of-line)
      ("k" beginning-of-buffer)
      ("g" beginning-of-buffer)
      ("j" end-of-buffer)))
    ("G" avy-goto-char-timer)
    (":" ele/goto-line)

    ("v" :hydra
     '(hydra-visual
       (:columns 4)
       "A hydra for scrolling"
       ("h" (lambda () (interactive) (scroll-right 10)) "Scroll left")
       ("l" (lambda () (interactive) (scroll-left 10)) "Scroll right")
       ("j" (lambda () (interactive) (scroll-up 15)) "Scroll down")
       ("k" (lambda () (interactive) (scroll-down 15)) "Scroll up")
       ("," avy-pop-mark "Go to previous mark")
       ("." goto-last-change "Goto last change")
       ("+" (lambda () (interactive) (text-scale-increase 1)) "Increase Font Size")
       ("-" (lambda () (interactive) (text-scale-decrease 1)) "Decrease Font Size")
       ("0" (lambda () (interactive) (text-scale-increase 0)) "Reset Font Size" :exit t)
       ("c" ele/toggle-theme "Toggle bright theme" :exit t)
       ("v" recenter "Center cursor" :exit t)
       ("e" next-error "Next error")
       ("E" previous-error "Previous error")
       ("q" nil "Cancel")))

    ; kill-ring
    ("y" kill-ring-save)
    ("d" ele/delete)
    ("D" ele/delete-no-kill)
    ("p" ele/yank)

    ; selection
    ("." er/expand-region)
    ("x" ele/expand-line)
    ("%" mark-whole-buffer)
    ("m" ele/exchange-point-and-mark)
    ("M" ele/activate-mark)
    ("SPC" ele/keyboard-quit)
    ("w" :hydra
     '(hydra-smartparens
       (:columns 4)
       "Smartparens"
       ("(" sp-backward-slurp-sexp "Move Left Wrapper Left")
       (")" sp-backward-barf-sexp "Move Left Wrapper Right")
       ("<left>" sp-forward-barf-sexp "Move Right Wrapper Left")
       ("<right>" sp-forward-slurp-sexp "Move Right Wrapper Left")
       ("c" sp-rewrap-sexp "Change Wrapping Pair" :exit t)
       ("d" sp-splice-sexp "Delete Wrapping Pair" :exit t)
       ("r" sp-raise-sexp "Raise Sexp")
       ("R" (lambda () (interactive) (sp-raise-sexp '(16))) "Raise Enclosing Sexp")
       ("s" sp-split-sexp "Split Sexp")
       ("S" sp-join-sexp "Unsplit (join) Sexps")
       ("q" nil "Cancel")))

    ; window management
    ("TAB" ele/switch-window)
    ("<C-tab>" ele/toggle-vertical-split)
    ("<backtab>" delete-other-windows)

    ; parens and brackets and stuff
    ("(" corral-parentheses-backward)
    (")" corral-parentheses-forward)
    ("[" corral-brackets-backward)
    ("]" corral-brackets-forward)
    ("{" corral-braces-backward)
    ("}" corral-braces-forward)

    ; macros
    ("Q" ele/define-or-end-macro)
    ("q" kmacro-call-macro)

    ; misc
    (">" ele/indent)
    ("<" ele/dedent)
    ("M-j" ele/join-line)
    ("u" undo)
    ("|" ele/shell-command)
    ("t" ele/c-god)
    ("z" bm-next)
    ("Z" bm-toggle)
    ("S" sam-eval-last-command)
    ("C" ele/toggle-case)

    ; leader key
    (","
     (("c" ele/comment)
      ("t"
       (("t" ele/insert-todo)
        ("n" ele/insert-note)
        ("o" ele/insert-opt)))
      ("p" projectile-find-file)
      ("b" switch-to-buffer)
      ("f" find-file)
      ("e" ele/edit-emacs-config)
      ("," smex)
      ("s" ele/save-all)
      ("i" ele/increment-number-decimal)
      ("SPC" ele/shell-and-update-output)
      ("w" fill-paragraph)
      ("q" save-buffers-kill-terminal)))

    ; insert mode
    ("o" ele/open-line-below :then '(ele/exit-command-mode))
    ("O" ele/open-line-above :then '(ele/exit-command-mode))
    ("c" ele/change)
    ("i" ele/insert)
    ("a" ele/append)
    ("A" end-of-line :then '(deactivate-mark ele/exit-command-mode))
    ("I" beginning-of-line :then '(deactivate-mark ele/exit-command-mode)))

  ; Set up prefix arguments
  (ryo-modal-keys
   ("0" "M-0")
   ("1" "M-1")
   ("2" "M-2")
   ("3" "M-3")
   ("4" "M-4")
   ("5" "M-5")
   ("6" "M-6")
   ("7" "M-7")
   ("8" "M-8")
   ("9" "M-9")))


; ==== Other packages ====

(add-to-list 'auto-mode-alist '("\\.svelte\\'" . html-mode))

(use-package whitespace
  :hook (makefile-mode . whitespace-mode)
  :config
  (setq whitespace-style '(face tabs spaces tab-mark))
  (setq whitespace-space-regexp "\\(^ +\\)")
  (setq whitespace-tab-regexp "\\(^\t+\\)"))

(use-package proof-general
  :config
  (setq proof-splash-enable nil)
  (setq coq-compile-before-require t))

(use-package tuareg
    :mode ("\\.ml(|i|y|l|p)\\'" . tuareg-mode))

(use-package merlin
        :after (company tuareg)
        :hook (tuareg-mode . merlin-mode))

; TODO: this doesn't actually start tsserver (tide-restart[..]) or turn on flycheck (flycheck-mode)
(use-package tide
    :after (typescript-mode company flycheck)
    :hook
    ((typescript-mode . tide-setup)
     (typescript-mode . tide-hl-identifier-mode)))

(use-package typescript-mode
    :mode ("\\.ts\\'" . typescript-mode))

(use-package purescript-mode
  :hook (purescript-mode . turn-on-purescript-indentation))

(use-package elm-mode
  :mode ("\\.elm\\'" . elm-mode)
  :config
  (when (executable-find "elm-format")
    (add-hook 'elm-mode-hook 'elm-format-on-save-mode)))

(use-package rust-mode
  :mode ("\\.rs\\'" . rust-ts-mode))
;; (use-package rustic
;;   :mode ("\\.rs\\'" . rustic-mode)
;;   :config
;;   (setq rustic-lsp-client 'eglot)
;;   (setq rustic-use-rust-save-some-buffers t)
;;   (setq rustic-format-trigger 'on-save))
(use-package flycheck-rust
  :after rust-mode
  :hook (flycheck-mode . flycheck-rust-setup))

(use-package haskell-mode
  :ryo
  (:mode 'haskell-mode))

(use-package matlab
  :ensure matlab-mode
  :mode ("\\.m\\'" . matlab-mode))

(use-package z3-mode
  :mode ("\\.smt[2]?$" . z3-mode))

(use-package go-mode
  :mode ("\\.go\\'" . go-mode));; TODO(vipa, 2021-01-31): Should setup gofmt-before-save, but it should only be run when in go-mode, which the mode itself doesn't solve for me...

(use-package stan-mode
    :mode ("\\.stan\\'" . stan-mode)
    :hook (stan-mode . stan-mode-setup)
    ;;
    :config
    ;; The officially recommended offset is 2.
    (setq stan-indentation-offset 2))

(use-package company-stan
  :hook (stan-mode . company-stan-setup)
  :config
  ;; Whether to use fuzzy matching in `company-stan'
  (setq company-stan-fuzzy nil))

(use-package minizinc-mode
  :mode ("\\.mzn\\'" . minizinc-mode))

(use-package nix-mode
  :mode "\\.nix\\'")

;; (use-package omnisharp
;;   :after (company)
;;   :hook (csharp-mode . omnisharp-mode)
;;   :config
;;   (add-to-list 'company-backends #'company-omnisharp))

(use-package mcore-mode
  :ensure nil
  :mode ("\\.mc\\'" . mcore-mode))

(use-package miking-syn-mode
  :ensure nil
  :mode ("\\.syn\\'" . miking-syn-mode))

(use-package fish-mode
  :mode ("\\.fish\\'" . fish-mode))

(use-package jq-mode
  :mode ("\\.jq\\'" . jq-mode))

(use-package typst-ts-mode
  :ensure nil
  :mode ("\\.typ\\'" . typst-ts-mode))

(use-package languagetool
  :commands (languagetool-check
             languagetool-clear-suggestions
             languagetool-correct-at-point
             languagetool-correct-buffer
             languagetool-set-language
             languagetool-server-mode
             languagetool-server-start
             languagetool-server-stop))

(use-package markdown-mode
  :commands (markdown-mode gfm-mode)
  :mode (("README\\.md\\'" . gfm-mode)
         ("\\.md\\'" . markdown-mode)
         ("\\.markdown\\'" . markdown-mode))
  :config
  (define-key markdown-mode-map (kbd "<S-iso-lefttab>") nil)
  (setq markdown-fontify-code-blocks-natively t))

(use-package lua-mode
  :mode ("\\.lua\\'" . lua-mode))

(use-package gdscript-mode
  :mode ("\\.gd\\'" . gdscript-mode))

(use-package uiua-ts-mode
  :mode "\\.ua\\'")

(when (executable-find "direnv")
  (use-package envrc
    :config
    (envrc-global-mode)))

(use-package esup)

; ==== Custom stuff (can't seem to make it not appear, at least for the moment) ====

(setq custom-file (concat user-emacs-directory "custom.el"))
(load custom-file 'noerror)
