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

;;; Housekeeping

;; The Customize UI appends to init.el by default and rewrites whatever it
;; wrote before. Point it at its own file so this one stays hand-written.
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file))

;; Keep backup files out of project directories
(setq backup-directory-alist
      `(("." . ,(expand-file-name "backups" user-emacs-directory))))

;;; Editing behaviour

(show-paren-mode 1)                  ; highlight the matching paren under point
(electric-pair-mode 1)               ; auto-insert closing paren, quote, bracket
(column-number-mode 1)               ; show column number in the mode line
(global-display-line-numbers-mode 1) ; line numbers in every buffer
