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


;;; Command palette and project search

;; M-x through vertico already behaves like a command palette; these
;; add the VS Code keys on top. On the Mac port, Cmd is the super key,
;; so s-p is Cmd+P. Rebinding it also frees Cmd+P from the macOS print
;; dialog, which nobody has ever wanted from a text editor.
;; consult-ripgrep shells out to rg:  brew install ripgrep
(global-set-key (kbd "s-P") #'execute-extended-command) ; Cmd+Shift+P: command palette
(global-set-key (kbd "s-p") #'project-find-file)        ; Cmd+P: fuzzy find file in project
(global-set-key (kbd "s-F") #'consult-ripgrep)          ; Cmd+Shift+F: live grep the project


;;; Editing behaviour

(show-paren-mode 1)                   ; highlight the matching paren under point
(electric-pair-mode 1)                ; auto-insert closing paren, quote, bracket
(column-number-mode 1)                ; show column number in the mode line
(delete-selection-mode 1)             ; type over selected region, not deselect
(save-place-mode 1)                   ; remember cursor position between sessions


;;; Multiple cursors

;; VS Code style multi-edit. C-g collapses back to a single cursor.
;; The first time an unfamiliar command runs while cursors are active,
;; mc asks whether to apply it to all of them and remembers the answer
;; (the list lands in var/ thanks to no-littering).
(use-package multiple-cursors
  :bind (("s-d"         . mc/mark-next-like-this)   ; Cmd+D: mark next occurrence
         ("s-L"         . mc/mark-all-like-this)    ; Cmd+Shift+L: mark all occurrences
         ("C-S-c C-S-c" . mc/edit-lines)            ; cursor on every line of the region
         ("s-<mouse-1>" . mc/add-cursor-on-click))) ; Cmd+click to place cursors


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


;;; Windows and panels

;; The layout model: normal windows in the middle for editing, side
;; windows docked around the edges for panels. Side windows are built
;; in; display-buffer-alist below decides which buffers become panels
;; and where they dock. Treemacs sits in a left side window, the
;; terminal docks at the bottom, Claude docks on the right.

;; Undo for window layouts. C-c <left> restores the previous
;; arrangement after something blows yours away.
(winner-mode 1)

;; Repeating commands drop their prefix: C-x o o o keeps cycling
;; windows, C-x { { { keeps shrinking. Built in since Emacs 28.
(repeat-mode 1)

;; Jump to any window by home-row letter. With only two windows it
;; skips the letters and just switches.
(use-package ace-window
  :bind ("M-o" . ace-window)
  :custom
  (aw-keys '(?a ?s ?d ?f ?g ?h ?j ?k ?l)))

;; Which buffers dock where. Each entry: a regexp on the buffer name,
;; a display function, then placement and size.
(setq display-buffer-alist
      '(("\\*vterm\\*"
         (display-buffer-in-side-window)
         (side . bottom)
         (window-height . 0.3))
        ("\\*Claude\\*"
         (display-buffer-in-side-window)
         (side . right)
         (window-width . 0.4))))

;; Make C-x b respect the rules above, so switching to *vterm* sends
;; it to its panel instead of taking over the current window.
(setq switch-to-buffer-obey-display-actions t)

(defun joey/dock-buffer (side)
  "Dock the current buffer to SIDE as a side window.
SIDE is left, right, top or bottom. Any buffer can become a panel
this way: eww, help, compilation output. Undo with C-c <left>."
  (interactive
   (list (intern (completing-read "Dock side: "
                                  '(left right top bottom) nil t))))
  (let ((buf (current-buffer)))
    (if (window-deletable-p)
        (delete-window)
      (switch-to-prev-buffer))
    (select-window
     (display-buffer-in-side-window
      buf
      (list (cons 'side side)
            (if (memq side '(left right))
                '(window-width . 0.35)
              '(window-height . 0.3)))))))

;; C-c w: the window and panel keymap.
(global-set-key (kbd "C-c w d") #'joey/dock-buffer)          ; dock buffer to a side
(global-set-key (kbd "C-c w t") #'window-toggle-side-windows) ; hide/show all panels
(global-set-key (kbd "C-c w =") #'balance-windows)           ; equalize sizes

;; Resize the current window from the keyboard. Dragging the divider
;; between windows with the mouse also works.
(global-set-key (kbd "C-s-<up>")    #'enlarge-window)
(global-set-key (kbd "C-s-<down>")  #'shrink-window)
(global-set-key (kbd "C-s-<left>")  #'shrink-window-horizontally)
(global-set-key (kbd "C-s-<right>") #'enlarge-window-horizontally)


;;; File tree

;; A project sidebar on the left, VS Code style. dired stays around
;; for real file management; this is for orientation and quick opens.
(use-package treemacs
  :bind ("s-b" . treemacs)              ; Cmd+B: toggle the sidebar
  :config
  (setq treemacs-width 32)
  (treemacs-follow-mode 1)              ; highlight the file being edited
  (treemacs-filewatch-mode 1))          ; pick up external file changes


;;; Terminal

;; vterm is a real terminal emulator backed by libvterm, so shells,
;; colors and curses apps behave. The package compiles a small C
;; module on first launch, which needs two build tools:
;;   brew install cmake libtool
(use-package vterm
  :commands vterm
  :config
  (setq vterm-always-compile-module t)  ; skip the compile prompt
  (setq vterm-max-scrollback 10000)
  ;; vterm swallows most keys and sends them to the shell. Carve the
  ;; toggle key back out so it closes the panel from inside too.
  (define-key vterm-mode-map (kbd "C-`") #'joey/toggle-vterm))

(defun joey/toggle-vterm ()
  "Toggle the terminal panel at the bottom of the frame."
  (interactive)
  (if-let* ((win (get-buffer-window "*vterm*")))
      (delete-window win)
    (let ((buf (or (get-buffer "*vterm*")
                   (save-window-excursion
                     (vterm)
                     (get-buffer "*vterm*")))))
      (select-window (display-buffer buf)))))

(global-set-key (kbd "C-`") #'joey/toggle-vterm)  ; same key as VS Code


;;; Claude

;; gptel turns any buffer into a chat. The panel below is a normal
;; org-mode buffer: headings per exchange, foldable, saveable. Inside
;; it, C-c RET sends; C-u C-c RET opens the menu to switch models,
;; add files to context, or redirect the response.
;;
;; The key lives in ~/.authinfo (chmod 600), one line:
;;   machine api.anthropic.com login apikey password sk-ant-yourkey
(use-package gptel
  :commands (gptel gptel-send)
  :config
  (setq gptel-default-mode 'org-mode)
  (setq gptel-model 'claude-sonnet-4-6  ; fast default for chat
        gptel-backend (gptel-make-anthropic "Claude"
                        :stream t
                        :key gptel-api-key  ; resolves via ~/.authinfo
                        :models '(claude-sonnet-4-6
                                  claude-opus-4-8
                                  claude-haiku-4-5-20251001
                                  claude-fable-5))))

(defun joey/toggle-claude ()
  "Toggle the Claude panel on the right."
  (interactive)
  (if-let* ((win (get-buffer-window "*Claude*")))
      (delete-window win)
    (select-window (display-buffer (gptel "*Claude*")))))

(global-set-key (kbd "s-l") #'joey/toggle-claude)  ; Cmd+L, as in Cursor


;;; Browser

;; Emacs ships two browsers. eww renders pages as simplified text and
;; is always available. xwidget-webkit embeds real WebKit, but only
;; when the binary was built with it; check with
;; M-: (featurep 'xwidget-internal) and rebuild if you want it:
;;   brew reinstall emacs-plus@31 --with-xwidgets
;; joey/browse picks whichever the running Emacs supports.
(setq eww-auto-rename-buffer 'title)  ; readable names for multiple pages

(defun joey/browse (url)
  "Open URL in Emacs. WebKit when compiled in, eww otherwise.
Bare words become a DuckDuckGo search either way."
  (interactive "sURL or search: ")
  (if (featurep 'xwidget-internal)
      (xwidget-webkit-browse-url
       (cond ((string-match-p "\\`[a-z]+://" url) url)
             ((string-match-p "\\." url) (concat "https://" url))
             (t (concat "https://duckduckgo.com/html/?q="
                        (url-hexify-string url)))))
    (eww url)))

(global-set-key (kbd "C-c b") #'joey/browse)


;;; Org

;; Plain text with superpowers: outlines, TODO tracking, agenda,
;; capture. Everything lives under ~/org. C-c c files a thought into
;; inbox.org without leaving what you're doing; C-c a shows the agenda
;; across every org file in the directory.
(use-package org
  :ensure nil                           ; built in, nothing to fetch
  :bind (("C-c a" . org-agenda)
         ("C-c c" . org-capture)
         ("C-c l" . org-store-link))
  :config
  (setq org-directory "~/org"
        org-default-notes-file (expand-file-name "inbox.org" org-directory)
        org-agenda-files (list org-directory)
        org-startup-indented t          ; indent body text under its heading
        org-hide-emphasis-markers t     ; render *bold* as bold, hide the stars
        org-return-follows-link t
        org-log-done 'time)             ; timestamp TODOs when they close
  (make-directory org-directory t)      ; agenda errors if the dir is missing
  (setq org-capture-templates
        '(("t" "Todo" entry (file+headline "" "Tasks")
           "* TODO %?\n  %U")
          ("n" "Note" entry (file+headline "" "Notes")
           "* %?\n  %U"))))

;;; init.el ends here