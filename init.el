;;; init.el --- Personal Emacs configuration -*- lexical-binding: t; -*-

;;; Package management

;; package.el ships with Emacs but needs loading before use.
(require 'package)

;; GNU ELPA is the only archive enabled by default and it's sparse.
;; MELPA carries nearly everything. The trailing t appends, so GNU
;; stays first in priority.
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)

;; Read the local package directory and put installed packages on the
;; load path. Must run before use-package declarations are evaluated.
(package-initialize)

;; use-package is built in as of Emacs 29. always-ensure makes every
;; declaration auto-install if missing, so cloning this repo onto a new
;; machine and launching Emacs is the whole setup.
(require 'use-package)
(setq use-package-always-ensure t)


;;; Bootstrap
;; Anything here has to load before the rest of the config, either
;; because other things depend on it or because it changes where files
;; get written.

;; GUI Emacs on macOS doesn't inherit the shell environment, so it can't
;; find Homebrew binaries, compilers, etc. This copies PATH in from a
;; real shell. Guarded to GUI frames only; terminal Emacs already has it.
(use-package exec-path-from-shell
  :if (memq window-system '(mac ns))
  :config
  (exec-path-from-shell-initialize))

;; Relocates package state files into etc/ (config) and var/ (data)
;; instead of scattering them through .emacs.d. Only redirects things
;; that haven't already chosen a path, so it must load before the modes
;; that write files. :demand overrides use-package's default deferral.
(use-package no-littering
  :demand t
  :config
  (no-littering-theme-backups))


;;; Housekeeping

;; The Customize UI appends to init.el by default and rewrites whatever
;; it wrote before. Point it at its own file so this one stays
;; hand-written. The guard is because the file won't exist until Emacs
;; first writes to it, and load errors on a missing file.
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file))

;; Reload buffers when the file changes on disk. Matters most when
;; switching git branches under a live Emacs.
(global-auto-revert-mode 1)
(setq global-auto-revert-non-file-buffers t)

;; Stop asking permission to follow symlinks into version-controlled files
(setq vc-follow-symlinks t)

;; Track recently opened files. Feeds consult-buffer below.
(recentf-mode 1)


;;; Appearance

;(use-package catppuccin-theme
;  :config
;  (setq catppuccin-flavor 'mocha)  ; 'latte 'frappe 'macchiato 'mocha
;  (load-theme 'catppuccin :no-confirm))

(use-package zenburn-theme
  :config
  (load-theme 'zenburn :no-confirm))

(tool-bar-mode -1)                    ; remove the icon strip
(scroll-bar-mode -1)
;; (setq inhibit-startup-screen t)    ; uncomment for scratch buffer on launch
(setq ring-bell-function 'ignore)     ; stop the flash/beep
(setq use-short-answers t)            ; y/n instead of typing yes/no

;; Line numbers only where they're useful. prog-mode is the parent of
;; every programming major mode, so this covers elisp, C, python, etc.
(global-display-line-numbers-mode -1)
(add-hook 'prog-mode-hook #'display-line-numbers-mode)

;; Press any prefix key, pause, and get a popup of every continuation.
;; Built in as of Emacs 30.
(which-key-mode 1)


;;; Completion

;; Vertical candidate list in the minibuffer, replacing the default
;; horizontal *Completions* buffer.
(use-package vertico
  :init
  (vertico-mode 1))

;; Space-separated matching in any order: "ini el" finds init.el.
;; Overrides the default prefix-only matching. Files keep the built-in
;; styles so path completion still behaves.
(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles basic partial-completion)))))

;; Annotations beside candidates: docstrings for commands, sizes and
;; modes for files.
(use-package marginalia
  :init
  (marginalia-mode 1))

;; Better versions of common commands, with live preview.
(use-package consult
  :bind (("C-x b"   . consult-buffer)          ; buffers + recent files + bookmarks
         ("C-x p b" . consult-project-buffer)
         ("M-y"     . consult-yank-pop)        ; browse the kill ring
         ("C-s"     . consult-line)            ; search with all matches listed
         ("M-g g"   . consult-goto-line)
         ("M-g i"   . consult-imenu)))         ; jump to function/section in file


;;; Editing behaviour

(show-paren-mode 1)                   ; highlight the matching paren under point
(electric-pair-mode 1)                ; auto-insert closing paren, quote, bracket
(column-number-mode 1)                ; show column number in the mode line
(delete-selection-mode 1)             ; type over selected region, not deselect
(save-place-mode 1)                   ; remember cursor position between sessions


;;; Indentation

;; setq-default rather than setq because these are buffer-local, and
;; setq would only affect whatever buffer happens to be current here.
(setq-default indent-tabs-mode nil)   ; spaces, not tabs
(setq-default tab-width 4)

;; CC Mode applies a style when c-mode starts, which sets c-basic-offset
;; after init.el has already run. Set the style here, then override the
;; offset in a hook so the value lands afterward. Named function rather
;; than a lambda so re-evaluating this file doesn't stack duplicates.
(setq c-default-style "k&r")

(defun joey/c-indent-setup ()
  "Set C indentation width."
  (setq c-basic-offset 4))

(add-hook 'c-mode-hook #'joey/c-indent-setup)

;;; init.el ends here
