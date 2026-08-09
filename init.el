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


(tool-bar-mode -1)                    ; remove the icon strip
(scroll-bar-mode -1)
;; (setq inhibit-startup-screen t)    ; uncomment for scratch buffer on launch
(setq ring-bell-function 'ignore)     ; stop the flash/beep
(setq use-short-answers t)            ; y/n instead of typing yes/no

(global-hl-line-mode 1)               ; highlight current line
(set-face-attribute 'hl-line nil :background "#4F4F4F")

(use-package zenburn-theme
  :config
  (load-theme 'zenburn :no-confirm))

;; Line numbers only where they're useful. prog-mode is the parent of
;; every programming major mode, so this covers elisp, C, python, etc.
(global-display-line-numbers-mode -1)
(add-hook 'prog-mode-hook #'display-line-numbers-mode)

;; Press any prefix key, pause, and get a popup of every continuation.
;; Built in as of Emacs 30.
(which-key-mode 1)

;; line spaceing increase
(setq-default line-spacing 0.25)  ; fraction of line height, or an integer for pixels

;; Spacious padding to add some breathing room
(use-package spacious-padding
  :ensure t
  :custom
  (spacious-padding-widths
   '(:internal-border-width 16
     :right-divider-width 16
     :fringe-width 8
     :mode-line-width 4))
  :config
  (spacious-padding-mode 1))

;; Fonts are different for text vs code
;; Prose font
(set-face-attribute 'variable-pitch nil
                    :family "iA Writer Quattro V"
                    :height 1.1)

;; Fallback mono face used inside prose buffers (match your code font)
(set-face-attribute 'fixed-pitch nil
                    :family "JetBrains Mono")

;; Any text-mode descendant (org, markdown, plain .txt) gets it
(add-hook 'text-mode-hook #'variable-pitch-mode)


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


;;; Moving selected text up and down
(use-package move-text
  :ensure t
  :bind (("M-<up>" . move-text-up)
         ("M-<down>" . move-text-down)))


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
;; a display function, then placement and size. Slots order multiple
;; panels on the same side: Claude sits above the cheatsheet when
;; both are open on the right.
(setq display-buffer-alist
      '(("\\`\\*vterm\\*\\'"
         (display-buffer-in-side-window)
         (side . bottom)
         (window-height . 0.3))
        ("\\*claude-code\\*"
         (display-buffer-in-direction)
         (direction . right)
         (window-width . 0.4))
        ("cheatsheet\\.org"
         (display-buffer-in-side-window)
         (side . right)
         (slot . 1)
         (window-width . 0.35))))

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


;;; Claude Code

;; Opens Claude Code in a vterm buffer docked to the right at 1/3
;; width. Runs `claude update` first (fast no-op when current), then
;; launches `claude`. Cmd+L toggles it open and closed.
(defun joey/toggle-claude-code ()
  "Toggle a Claude Code panel on the right side of the frame.
On first launch, prompt for a working directory (defaults to the
project root or the current buffer's directory)."
  (interactive)
  (let ((buf (get-buffer "*claude-code*")))
    (if-let* ((win (and buf (get-buffer-window buf))))
        (delete-window win)
      (if (and buf (get-buffer-process buf))
          (select-window (display-buffer buf))
        (when buf (kill-buffer buf))
        (let* ((default-dir (or (when-let* ((proj (project-current)))
                                  (project-root proj))
                                default-directory))
               (dir (read-directory-name "Claude Code in: " default-dir nil t))
               (default-directory dir))
          (require 'vterm)
          (setq buf (save-window-excursion
                      (vterm "*claude-code*")
                      (current-buffer)))
          (with-current-buffer buf
            (vterm-send-string "claude update 2>/dev/null; claude\n"))
          (select-window (display-buffer buf)))))))

(global-set-key (kbd "s-l") #'joey/toggle-claude-code)  ; Cmd+L


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


;;; Markdown

;; Emacs has no built-in markdown support. markdown-mode adds it, plus
;; two read-only "preview" modes that render in the buffer rather than
;; shelling out to a browser: markdown-view-mode and gfm-view-mode.
;; They hide the markup (**bold** shows as bold, no stars), scale the
;; headings, and syntax-highlight fenced code blocks. gfm- is the
;; GitHub flavour, which is what almost every README actually is.
;;
;; Since reading is the common case here, .md opens in the view mode
;; and C-c C-v flips to the editable mode. Swap gfm-view-mode for
;; gfm-mode in :mode below to reverse that default.
;;
;; The fonts: text-mode-hook up in Appearance turns on variable-pitch
;; for every text mode, and markdown-mode is one, so the two hooks
;; below take over for markdown specifically. Reading gets the prose
;; font, editing gets the code font. markdown's code and table faces
;; already inherit fixed-pitch, so fenced blocks stay monospaced in
;; the prose view.
(use-package markdown-mode
  :mode (("\\.md\\'"       . gfm-view-mode)
         ("\\.markdown\\'" . gfm-view-mode))
  :bind (:map markdown-mode-map
         ("C-c C-v" . joey/markdown-toggle-view))
  :custom
  (markdown-header-scaling t)              ; bigger type for bigger headings
  (markdown-fontify-code-blocks-natively t)
  :hook ((markdown-mode . joey/markdown-editing-faces)
         (markdown-view-mode . joey/markdown-reading-faces)
         (gfm-view-mode . joey/markdown-reading-faces)))

;; Both view modes derive from markdown-mode, so markdown-mode-hook
;; runs first and the view hook runs after, overriding it.
(defun joey/markdown-editing-faces ()
  "Code font, visible markup: the editing look."
  (variable-pitch-mode -1))

(defun joey/markdown-reading-faces ()
  "Prose font, wrapped lines: the reading look."
  (variable-pitch-mode 1)
  (visual-line-mode 1))

(defun joey/markdown-toggle-view ()
  "Switch the current buffer between markdown editing and reading.
Keeps point where it was."
  (interactive)
  (let ((pos (point)))
    (if (derived-mode-p 'markdown-view-mode 'gfm-view-mode)
        (progn
          (gfm-mode)
          ;; The view modes leave these behind; a major mode change
          ;; doesn't clear either one.
          (read-only-mode -1)
          (remove-from-invisibility-spec 'markdown-markup))
      (gfm-view-mode))
    (goto-char pos)))


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


;;; Cheatsheet

;; The keybinding reference is a plain org file living next to this
;; config. C-c h toggles it as a right-hand panel. The essentials sit
;; at the top; TAB on any heading below them unfolds the deeper stuff.
;; It's an ordinary file, so edit it as new bindings accumulate.
(defvar joey/cheatsheet-file
  (expand-file-name "cheatsheet.org" user-emacs-directory)
  "Where the keybinding cheatsheet lives.")

(defun joey/toggle-cheatsheet ()
  "Toggle the cheatsheet panel on the right."
  (interactive)
  (unless (file-exists-p joey/cheatsheet-file)
    (user-error "No cheatsheet at %s; put cheatsheet.org next to init.el"
                joey/cheatsheet-file))
  (let ((buf (find-file-noselect joey/cheatsheet-file)))
    (if-let* ((win (get-buffer-window buf)))
        (delete-window win)
      (select-window (display-buffer buf)))))

(global-set-key (kbd "C-c h") #'joey/toggle-cheatsheet)

;;; init.el ends here