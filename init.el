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

(use-package zenburn-theme
  :config
  (load-theme 'zenburn :no-confirm))

;; Face tweaks have to come after load-theme. A theme applies its own
;; version of every face it knows about, so anything set beforehand is
;; overwritten the moment the theme loads.
;;
;; hl-line highlights the single line point is on. It's off here because
;; joey/hl-block-mode below highlights the enclosing block instead, and
;; two backgrounds fighting over the same line looks muddy. Flip the 1
;; back on (and turn the block mode off) to go back to line highlighting.
(global-hl-line-mode -1)
(set-face-attribute 'hl-line nil :background "#4F4F4F")

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


;;; Block highlight

;; hl-line highlights one line. This highlights the smallest meaningful
;; chunk of text around point instead: the paragraph you're writing, the
;; list item you're on, the if statement you're inside, the function when
;; you're in its body but not in anything narrower.
;;
;; "Smallest meaningful chunk" is per-mode, so there's a dispatcher and
;; one bounds function per kind of buffer:
;;
;;   org        the element at point, via org-element
;;   markdown   heading line, list item, or paragraph
;;   code       innermost enclosing block, via tree-sitter when a grammar
;;              is loaded, otherwise by matching brackets
;;   text       the paragraph
;;
;; The common rule in code buffers is "innermost thing that spans more
;; than one line". That's what makes a bare statement inside a function
;; highlight the whole function, while the same statement inside an if
;; highlights just the if: the one-line pieces get skipped over and the
;; first multi-line ancestor wins.

(defface joey/hl-block '((t :extend t))
  "Face for the block highlight.
:extend makes the background run to the window edge on every line
rather than stopping at the end of the text.")

;; After the theme, same reason as hl-line above. Dimmer than hl-line's
;; grey because it covers a lot more of the screen.
(set-face-attribute 'joey/hl-block nil :background "#474747")

(defvar joey/hl-block-exclude-modes
  '(vterm-mode treemacs-mode dired-mode)
  "Major modes that never get a block highlight.
Terminals and sidebars have their own idea of the current line.")

(defun joey/hl-block--multiline-p (beg end)
  "Non-nil when the region BEG to END covers more than one line."
  (save-excursion
    (goto-char beg)
    (< (line-end-position) end)))

(defun joey/hl-block--trim (beg end)
  "Return (BEG . END) snapped to whole lines with blank lines trimmed.
Org elements in particular run to the start of the next element, which
means they swallow the blank line after themselves."
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
Headings highlight as the single heading line, not the whole subtree,
which is what makes moving down an outline feel like moving a cursor."
  (let ((el (org-element-at-point)))
    (if (eq (org-element-type el) 'headline)
        (cons (line-beginning-position) (line-end-position))
      ;; Point inside a bullet's text reports the paragraph, but the item
      ;; is the unit worth seeing, so climb to it when there is one.
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
  "Node types that count as a block. Grammars name things differently,
so this matches on substrings rather than listing every language's set.")

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
    ;; A brace body on its own excludes the line that gives it meaning:
    ;; the `if (...)' or the function signature. Step out to the parent so
    ;; the header is inside the highlight.
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
statement. Allman puts it on a line of its own, so the statement is the
line above. Anything that isn't a brace, such as a lisp paren, is already
at the right place."
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
  "Bounds of the innermost multi-line bracketed form around point.
The bracket depth from `syntax-ppss' gives every enclosing form from
outermost to innermost for free, so this walks that list inward-out and
stops at the first one tall enough to be worth drawing."
  (let ((opens (reverse (nth 9 (syntax-ppss))))   ; innermost first
        (result nil))
    (while (and opens (not result))
      (let* ((beg (car opens))
             (end (ignore-errors (scan-lists beg 1 0))))
        (when (and end (joey/hl-block--multiline-p beg end))
          (setq result (cons (joey/hl-block--statement-start beg) end))))
      (setq opens (cdr opens)))
    ;; Outside every bracket: a top-level defun, or just the line.
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
  "Move the block overlay to the block around point.
With no block at point, on a blank line say, the overlay goes away."
  ;; bound-and-true-p because the mode variable is created by the
  ;; define-minor-mode below this, and the byte compiler reads in order.
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
        ;; Below the region and search highlights, so selecting text
        ;; still reads clearly on top of the block.
        (overlay-put joey/hl-block--overlay 'priority -60))
      (move-overlay joey/hl-block--overlay
                    (car bounds)
                    ;; Take the newline too, so :extend has something to
                    ;; extend on the last line of the block.
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

;; CC Mode still handles any C-family language without a tree-sitter
;; mode below, so the style stays set here. CC Mode applies its style
;; when the mode starts, which is after init.el has run, so the offset
;; has to be re-set from a hook to land afterward. Named function rather
;; than a lambda so re-evaluating this file doesn't stack duplicates.
(setq c-default-style "k&r")

(defun joey/c-indent-setup ()
  "Set C indentation width for CC Mode buffers."
  (setq c-basic-offset 4))

(add-hook 'c-mode-hook #'joey/c-indent-setup)


;;; Tree-sitter

;; Emacs parses these languages for real rather than by regexp, which
;; buys better fontification, more reliable indentation, and structural
;; commands that understand nesting. joey/hl-block-mode picks the parse
;; tree over bracket matching whenever a buffer has a parser, so blocks
;; without braces highlight correctly too:
;;
;;   if (x > 0)
;;       do_thing();     <- brackets can't see this; the parser can
;;
;; Where the grammars come from. M-x treesit-install-language-grammar
;; reads this list, clones, compiles and drops a .dylib in
;; tree-sitter/. That needs git and a C compiler (Command Line Tools),
;; and only has to happen once per machine. The four below are already
;; built; add a language here and install it to add a fifth.
;;
;; Markdown is deliberately absent: Emacs 30 has no markdown-ts-mode,
;; and markdown-mode plus the block highlight already handle it.
;; Wren has no usable grammar and no Emacs mode, so it stays on CC-style
;; bracket matching, which its braces suit fine.
(require 'treesit)

(setq treesit-language-source-alist
      '((c          "https://github.com/tree-sitter/tree-sitter-c")
        (cpp        "https://github.com/tree-sitter/tree-sitter-cpp")
        (json       "https://github.com/tree-sitter/tree-sitter-json")
        (javascript "https://github.com/tree-sitter/tree-sitter-javascript")))

;; Send the classic modes to their tree-sitter equivalents. Remapping
;; rather than rewriting auto-mode-alist means every entry that already
;; points at c-mode gets redirected too, and unsetting one line here is
;; enough to fall back to CC Mode if a grammar ever misbehaves.
;;
;; treesit-ready-p guards each one: on a machine where the grammar isn't
;; built yet, the remap is skipped and the old mode handles the file,
;; rather than the buffer erroring out on open.
;; javascript-mode is an alias of js-mode, but it is the symbol
;; auto-mode-alist actually stores for .js, and remapping matches on the
;; stored symbol rather than resolving aliases. Both entries are needed.
(dolist (pair '((c-mode          . c-ts-mode)
                (c++-mode        . c++-ts-mode)
                (js-mode         . js-ts-mode)
                (javascript-mode . js-ts-mode)
                (js-json-mode    . json-ts-mode)))
  (let ((lang (pcase (cdr pair)
                ('c-ts-mode 'c) ('c++-ts-mode 'cpp)
                ('json-ts-mode 'json) ('js-ts-mode 'javascript))))
    (when (treesit-ready-p lang t)      ; t: stay quiet when missing
      (add-to-list 'major-mode-remap-alist pair))))

;; The ported indentation. c-ts-mode is not CC Mode, so it ignores
;; c-default-style and c-basic-offset entirely; these two are the
;; equivalents, and c++-ts-mode reads the same pair. Both are plain
;; options read at mode start, so unlike CC Mode no hook is needed.
(setq c-ts-mode-indent-style 'k&r)
(setq c-ts-mode-indent-offset 4)

;; The other two have their own offsets, both defaulting to 2. Set to 4
;; to match tab-width above; JSON in particular is conventionally 2, so
;; change json-ts-mode-indent-offset if that reads wrong to you.
(setq js-indent-level 4)              ; js-ts-mode
(setq json-ts-mode-indent-offset 4)


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