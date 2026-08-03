;;; Package management

;; package.el ships with Emacs but needs loading before use
(require 'package)

;; GNU ELPA is the only archive enabled by default and it's sparse.
;; MELPA carries nearly everything. The trailing t appends, so GNU
;; stays first in priority.
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)

;; Read the local package directory and put installed packages on the load path
(package-initialize)


;;; Bootstrap packages

;; Auto-install on a fresh machine so cloning this repo is the whole setup.
;; The unless guard means the network fetch only happens once, not every launch.
(unless (package-installed-p 'exec-path-from-shell)
  (package-refresh-contents)
  (package-install 'exec-path-from-shell))

;; GUI Emacs on macOS doesn't inherit the shell environment, so it can't
;; find Homebrew binaries, compilers, etc. This copies PATH in from a real
;; shell. Guarded to GUI frames only; terminal Emacs already has it.
(when (memq window-system '(mac ns))
  (exec-path-from-shell-initialize))

;; Set up catpuccin theme
(unless (package-installed-p 'catppuccin-theme)
  (package-refresh-contents)
  (package-install 'catppuccin-theme))

(setq catppuccin-flavor 'latte)  ; 'latte 'frappe 'macchiato 'mocha
(load-theme 'catppuccin :no-confirm)


;;; Housekeeping

;; The Customize UI appends to init.el by default and rewrites whatever it
;; wrote before. Point it at its own file so this one stays hand-written.
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file))

;; Reload buffers when the file changes on disk
(global-auto-revert-mode 1)
(setq global-auto-revert-non-file-buffers t)

;; Stop asking permission to follow symlinks into version-controlled files
(setq vc-follow-symlinks t)

;; Track recently opened files
(recentf-mode 1)

;; Relocates package state files into etc/ (config) and var/ (data)
;; instead of scattering them through .emacs.d. Must load early, before
;; the modes that would otherwise set their own paths.
(unless (package-installed-p 'no-littering)
  (package-refresh-contents)
  (package-install 'no-littering))
(require 'no-littering)

;; Backups and auto-saves into var/ as well
(no-littering-theme-backups)


;;; UI

(setq use-short-answers t)            ; y/n instead of typing yes/no
(tool-bar-mode -1)                   ; remove the icon strip
(scroll-bar-mode -1)
; (setq inhibit-startup-screen t)
(setq ring-bell-function 'ignore)    ; stop the flash/beep

(global-display-line-numbers-mode -1)
(add-hook 'prog-mode-hook #'display-line-numbers-mode) 


;;; Editing behaviour

(show-paren-mode 1)                  ; highlight the matching paren under point
(electric-pair-mode 1)               ; auto-insert closing paren, quote, bracket
(column-number-mode 1)               ; show column number in the mode
(delete-selection-mode 1)            ; type over selected region, not deselect
(save-place-mode 1)                  ; remember cursor position between sessions


;;; Indentation

(setq-default indent-tabs-mode nil)  ; spaces, not tabs
(setq-default tab-width 4)

(setq c-default-style "k&r")

(defun joey/c-indent-setup ()
  (setq c-basic-offset 4))

(add-hook 'c-mode-hook #'joey/c-indent-setup)
