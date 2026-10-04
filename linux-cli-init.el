;;; init.el --- Terminal-only Emacs config for the ssh/mosh dev box -*- lexical-binding: t; -*-

;;; Package management

(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

;; use-package is built in as of Emacs 29. always-ensure auto-installs
;; anything missing, so launching Emacs on a fresh box is the whole setup.
(require 'use-package)
(setq use-package-always-ensure t)


;;; Bootstrap

;; Moves package state files into etc/ and var/ instead of scattering
;; them through .emacs.d. Has to load before the modes that write files.
(use-package no-littering
  :demand t
  :config
  (no-littering-theme-backups))


;;; Housekeeping

;; Keep Customize's output out of this hand-written file.
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file))

(global-auto-revert-mode 1)
(setq global-auto-revert-non-file-buffers t)
(setq vc-follow-symlinks t)
(recentf-mode 1)
(save-place-mode 1)


;;; Terminal niceties

;; Mouse clicks, scrolling and window dragging inside the terminal.
;; Works over ssh and mosh.
(unless (display-graphic-p)
  (xterm-mouse-mode 1))

;; Copy in Emacs, paste on your local machine. Clipetty sends the kill
;; ring to your local clipboard with an OSC 52 escape sequence, so it
;; rides along over ssh with nothing to forward. Your local terminal
;; has to allow OSC 52 (most do, some need a setting). Recent mosh
;; passes it through too.
(use-package clipetty
  :hook (after-init . global-clipetty-mode))


;;; Appearance

(menu-bar-mode -1)
(setq ring-bell-function 'ignore)
(setq use-short-answers t)

;; Zenburn looks best with 24-bit color. Over ssh that works when the
;; local terminal supports it. Over mosh it needs a recent version.
;; Otherwise Emacs approximates with 256 colors, which is still fine.
(use-package zenburn-theme
  :config
  (load-theme 'zenburn :no-confirm))

(global-display-line-numbers-mode -1)
(add-hook 'prog-mode-hook #'display-line-numbers-mode)

(which-key-mode 1)


;;; Block highlight

;; Highlights the smallest meaningful chunk around point: the paragraph
;; you're writing, the list item you're on, the if statement you're
;; inside, the function when you're in its body but nothing narrower.
;;
;;   org        the element at point, via org-element
;;   markdown   heading line, list item, or paragraph
;;   code       innermost enclosing block, via tree-sitter when a grammar
;;              is loaded, otherwise by matching brackets
;;   text       the paragraph
;;
;; In code buffers the rule is "innermost thing that spans more than one
;; line", so one-line pieces get skipped and the first multi-line
;; ancestor wins.

(defface joey/hl-block '((t :extend t))
  "Face for the block highlight.")

;; After the theme, since a theme overwrites faces set before it loads.
(set-face-attribute 'joey/hl-block nil :background "#474747")

(defvar joey/hl-block-exclude-modes
  '(vterm-mode treemacs-mode dired-mode)
  "Major modes that never get a block highlight.")

(defun joey/hl-block--multiline-p (beg end)
  "Non-nil when the region BEG to END covers more than one line."
  (save-excursion
    (goto-char beg)
    (< (line-end-position) end)))

(defun joey/hl-block--trim (beg end)
  "Return (BEG . END) snapped to whole lines with blank lines trimmed."
  (when (and beg end (< beg end))
    (save-excursion
      (goto-char beg)
      (skip-chars-forward " \t\n" end)
      (let ((start (line-beginning-position)))
        (goto-char (min end (point-max)))
        (skip-chars-backward " \t\n" start)
        (cons start (line-end-position))))))

(defun joey/hl-block--paragraph-bounds ()
  "Bounds of the paragraph at point, or nil on a blank line."
  (unless (save-excursion (beginning-of-line) (looking-at-p "[ \t]*$"))
    (when-let* ((b (bounds-of-thing-at-point 'paragraph)))
      (joey/hl-block--trim (car b) (cdr b)))))

(defun joey/hl-block--org-bounds ()
  "Bounds of the org element at point.
Headings highlight as the single heading line, not the whole subtree."
  (let ((el (org-element-at-point)))
    (if (eq (org-element-type el) 'headline)
        (cons (line-beginning-position) (line-end-position))
      (when-let* ((item (org-element-lineage el '(item) t)))
        (setq el item))
      (joey/hl-block--trim (org-element-property :begin el)
                           (org-element-property :end el)))))

(defun joey/hl-block--markdown-bounds ()
  "Heading line, list item, or paragraph at point."
  (cond
   ((save-excursion (beginning-of-line) (looking-at-p "[ \t]*#+[ \t]"))
    (cons (line-beginning-position) (line-end-position)))
   ((and (fboundp 'markdown-cur-list-item-bounds)
         (markdown-cur-list-item-bounds))
    (let ((b (markdown-cur-list-item-bounds)))
      (joey/hl-block--trim (nth 0 b) (nth 1 b))))
   (t (joey/hl-block--paragraph-bounds))))

(defconst joey/hl-block--treesit-block-re
  "statement\\|definition\\|declaration\\|clause\\|block\\|function\\|method\\|class"
  "Node types that count as a block, matched on substrings.")

(defconst joey/hl-block--treesit-body-re
  "\\`\\(compound_statement\\|block\\|statement_block\\)\\'"
  "Node types that are a bare body, with the interesting part outside them.")

(defun joey/hl-block--treesit-bounds ()
  "Bounds of the innermost multi-line block node around point."
  (let ((node (treesit-node-at (point)))
        (found nil))
    (while (and node (not found))
      (when (and (string-match-p joey/hl-block--treesit-block-re
                                 (treesit-node-type node))
                 (joey/hl-block--multiline-p (treesit-node-start node)
                                             (treesit-node-end node)))
        (setq found node))
      (setq node (treesit-node-parent node)))
    ;; A brace body alone leaves out the `if (...)' or the function
    ;; signature, so step out to the parent to include the header.
    (when (and found
               (string-match-p joey/hl-block--treesit-body-re
                               (treesit-node-type found))
               (treesit-node-parent found))
      (setq found (treesit-node-parent found)))
    (when found
      (cons (treesit-node-start found) (treesit-node-end found)))))

(defun joey/hl-block--statement-start (beg)
  "Back BEG up from an opening brace to the head of its statement.
K&R puts the brace at the end of the `if' line, so the line start is the
statement. Allman puts it on its own line, so the statement is the line
above. Anything that isn't a brace is already at the right place."
  (save-excursion
    (goto-char beg)
    (if (not (eq (char-after) ?\{))
        beg
      (skip-chars-backward " \t")
      (when (bolp)
        (forward-line -1))
      (back-to-indentation)
      (point))))

(defun joey/hl-block--sexp-bounds ()
  "Bounds of the innermost multi-line bracketed form around point."
  (let ((opens (reverse (nth 9 (syntax-ppss))))   ; innermost first
        (result nil))
    (while (and opens (not result))
      (let* ((beg (car opens))
             (end (ignore-errors (scan-lists beg 1 0))))
        (when (and end (joey/hl-block--multiline-p beg end))
          (setq result (cons (joey/hl-block--statement-start beg) end))))
      (setq opens (cdr opens)))
    (or result
        (if-let* ((b (bounds-of-thing-at-point 'defun)))
            (joey/hl-block--trim (car b) (cdr b))
          (unless (save-excursion (beginning-of-line) (looking-at-p "[ \t]*$"))
            (cons (line-beginning-position) (line-end-position)))))))

(defun joey/hl-block-bounds ()
  "Bounds of the block around point in the current buffer, or nil.
Errors are swallowed: this runs after every command, and a parser
complaining about half-typed code shouldn't interrupt typing."
  (ignore-errors
    (cond
     ((derived-mode-p 'org-mode)      (joey/hl-block--org-bounds))
     ((derived-mode-p 'markdown-mode) (joey/hl-block--markdown-bounds))
     ((and (fboundp 'treesit-parser-list) (treesit-parser-list))
      (joey/hl-block--treesit-bounds))
     ((derived-mode-p 'prog-mode)     (joey/hl-block--sexp-bounds))
     (t (joey/hl-block--paragraph-bounds)))))

;; One overlay per buffer, moved rather than recreated, so this stays
;; cheap enough to run on post-command-hook.
(defvar-local joey/hl-block--overlay nil)

(defun joey/hl-block--update ()
  "Move the block overlay to the block around point."
  (let ((bounds (and (bound-and-true-p joey/hl-block-mode)
                     (not (minibufferp))
                     (joey/hl-block-bounds))))
    (cond
     ((null bounds)
      (when (overlayp joey/hl-block--overlay)
        (delete-overlay joey/hl-block--overlay)))
     (t
      (unless (overlayp joey/hl-block--overlay)
        (setq joey/hl-block--overlay (make-overlay 1 1 nil nil t))
        (overlay-put joey/hl-block--overlay 'face 'joey/hl-block)
        ;; Below the region and search highlights.
        (overlay-put joey/hl-block--overlay 'priority -60))
      (move-overlay joey/hl-block--overlay
                    (car bounds)
                    (min (point-max) (1+ (cdr bounds)))
                    (current-buffer))))))

(define-minor-mode joey/hl-block-mode
  "Highlight the block, paragraph or statement surrounding point."
  :lighter nil
  (if joey/hl-block-mode
      (add-hook 'post-command-hook #'joey/hl-block--update nil t)
    (remove-hook 'post-command-hook #'joey/hl-block--update t)
    (when (overlayp joey/hl-block--overlay)
      (delete-overlay joey/hl-block--overlay))))

(define-globalized-minor-mode joey/global-hl-block-mode
  joey/hl-block-mode
  (lambda ()
    (unless (or (minibufferp)
                (derived-mode-p joey/hl-block-exclude-modes))
      (joey/hl-block-mode 1)))
  :group 'convenience)

(joey/global-hl-block-mode 1)


;;; Completion

(use-package vertico
  :init
  (vertico-mode 1))

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles basic partial-completion)))))

(use-package marginalia
  :init
  (marginalia-mode 1))

;; consult-ripgrep needs rg:  sudo dnf install ripgrep
;; Project file finding is built in: C-x p f
(use-package consult
  :bind (("C-x b"   . consult-buffer)
         ("C-x p b" . consult-project-buffer)
         ("M-y"     . consult-yank-pop)
         ("C-s"     . consult-line)
         ("M-g g"   . consult-goto-line)
         ("M-g i"   . consult-imenu)
         ("M-s r"   . consult-ripgrep)))


;;; Editing behaviour

(show-paren-mode 1)
(electric-pair-mode 1)
(column-number-mode 1)
(delete-selection-mode 1)

;; Terminals can't send C-> or Cmd+anything, so multiple cursors live
;; under C-c m. C-g collapses back to a single cursor.
(use-package multiple-cursors
  :bind (("C-c m n" . mc/mark-next-like-this)
         ("C-c m p" . mc/mark-previous-like-this)
         ("C-c m a" . mc/mark-all-like-this)
         ("C-c m l" . mc/edit-lines)))

;; M-<up> and M-<down> work in most terminals. If yours doesn't send
;; them, M-x move-text-up still works and you can rebind to taste.
(use-package move-text
  :bind (("M-<up>"   . move-text-up)
         ("M-<down>" . move-text-down)))


;;; Indentation

(setq-default indent-tabs-mode nil)
(setq-default tab-width 4)

;; CC Mode applies its style at mode start, after init.el has run, so
;; the offset is re-set from a hook.
(setq c-default-style "k&r")

(defun joey/c-indent-setup ()
  "Set C indentation width for CC Mode buffers."
  (setq c-basic-offset 4))

(add-hook 'c-mode-hook #'joey/c-indent-setup)


;;; Tree-sitter

;; Needs git and a C compiler on the box:
;;   sudo dnf install gcc gcc-c++ make git
;; Then run M-x treesit-install-language-grammar once per language below.
;; Until a grammar is built, the remap is skipped and the classic mode
;; handles the file, so nothing errors.
(require 'treesit)

(setq treesit-language-source-alist
      '((c          "https://github.com/tree-sitter/tree-sitter-c")
        (cpp        "https://github.com/tree-sitter/tree-sitter-cpp")
        (json       "https://github.com/tree-sitter/tree-sitter-json")
        (javascript "https://github.com/tree-sitter/tree-sitter-javascript")))

;; javascript-mode is an alias of js-mode, but auto-mode-alist stores
;; the alias symbol for .js, and remapping matches on the stored symbol,
;; so both entries are needed.
(dolist (pair '((c-mode          . c-ts-mode)
                (c++-mode        . c++-ts-mode)
                (js-mode         . js-ts-mode)
                (javascript-mode . js-ts-mode)
                (js-json-mode    . json-ts-mode)))
  (let ((lang (pcase (cdr pair)
                ('c-ts-mode 'c) ('c++-ts-mode 'cpp)
                ('json-ts-mode 'json) ('js-ts-mode 'javascript))))
    (when (treesit-ready-p lang t)
      (add-to-list 'major-mode-remap-alist pair))))

;; c-ts-mode ignores c-default-style and c-basic-offset; these are the
;; equivalents, and c++-ts-mode reads the same pair.
(setq c-ts-mode-indent-style 'k&r)
(setq c-ts-mode-indent-offset 4)
(setq js-indent-level 4)
(setq json-ts-mode-indent-offset 4)


;;; Windows and panels

(winner-mode 1)      ; C-c <left> undoes a window layout change
(repeat-mode 1)      ; C-x o o o keeps cycling windows

;; The terminal docks at the bottom, Claude and the cheatsheet on the right.
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

(setq switch-to-buffer-obey-display-actions t)

(global-set-key (kbd "C-c w t") #'window-toggle-side-windows)
(global-set-key (kbd "C-c w =") #'balance-windows)


;;; File tree

(use-package treemacs
  :bind ("C-c o t" . treemacs)
  :config
  (setq treemacs-width 32)
  (treemacs-follow-mode 1)
  (treemacs-filewatch-mode 1))


;;; Terminal panel

;; vterm compiles a small C module on first launch. It needs:
;;   sudo dnf install cmake libtool libvterm-devel gcc make
(use-package vterm
  :commands vterm
  :config
  (setq vterm-always-compile-module t)
  (setq vterm-max-scrollback 10000)
  ;; vterm swallows most keys, so carve the toggle back out.
  (define-key vterm-mode-map (kbd "C-c o v") #'joey/toggle-vterm))

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

(global-set-key (kbd "C-c o v") #'joey/toggle-vterm)


;;; Claude Code

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

(global-set-key (kbd "C-c o c") #'joey/toggle-claude-code)


;;; Cheatsheet

;; The keybinding reference is a plain org file living next to this
;; config. C-c h toggles it as a right-hand panel. The essentials sit at
;; the top; TAB on any heading below them unfolds the deeper stuff.
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


;;; Markdown

;; .md opens read-only with the markup hidden. C-c C-v flips to the
;; editable mode and back. Swap gfm-view-mode for gfm-mode below to
;; make editing the default. Header scaling is off because terminals
;; can't draw bigger text.
(use-package markdown-mode
  :mode (("\\.md\\'"       . gfm-view-mode)
         ("\\.markdown\\'" . gfm-view-mode))
  :bind (:map markdown-mode-map
         ("C-c C-v" . joey/markdown-toggle-view))
  :custom
  (markdown-header-scaling nil)
  (markdown-fontify-code-blocks-natively t)
  :hook ((markdown-view-mode . visual-line-mode)
         (gfm-view-mode . visual-line-mode)))

(defun joey/markdown-toggle-view ()
  "Switch the current buffer between markdown editing and reading.
Keeps point where it was."
  (interactive)
  (let ((pos (point)))
    (if (derived-mode-p 'markdown-view-mode 'gfm-view-mode)
        (progn
          (gfm-mode)
          (read-only-mode -1)
          (remove-from-invisibility-spec 'markdown-markup))
      (gfm-view-mode))
    (goto-char pos)))


;;; Org

(use-package org
  :ensure nil
  :bind (("C-c a" . org-agenda)
         ("C-c c" . org-capture)
         ("C-c l" . org-store-link))
  :config
  (setq org-directory "~/org"
        org-default-notes-file (expand-file-name "inbox.org" org-directory)
        org-agenda-files (list org-directory)
        org-startup-indented t
        org-hide-emphasis-markers t
        org-return-follows-link t
        org-log-done 'time)
  (make-directory org-directory t)
  (setq org-capture-templates
        '(("t" "Todo" entry (file+headline "" "Tasks")
           "* TODO %?\n  %U")
          ("n" "Note" entry (file+headline "" "Notes")
           "* %?\n  %U"))))

;;; init.el ends here
