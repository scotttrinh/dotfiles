;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
(setq doom-font (font-spec :family "Geist Mono" :size 14)
      doom-variable-pitch-font (font-spec :family "Geist" :size 16))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doric-copper)

(require 'cl-lib)
(require 'color)

(defconst scott/diff-soften-background-blend 0.6
  "How much to blend diff backgrounds toward the default background.")

(defconst scott/diff-soften-faces
  '(magit-diff-added
    magit-diff-removed
    magit-diff-base
    magit-diff-our
    magit-diff-their
    magit-diff-added-highlight
    magit-diff-removed-highlight
    magit-diff-base-highlight
    magit-diff-our-highlight
    magit-diff-their-highlight
    ediff-current-diff-A
    ediff-current-diff-B
    ediff-current-diff-C
    ediff-current-diff-Ancestor
    ediff-fine-diff-A
    ediff-fine-diff-B
    ediff-fine-diff-C
    ediff-fine-diff-Ancestor
    ediff-even-diff-A
    ediff-even-diff-B
    ediff-even-diff-C
    ediff-even-diff-Ancestor
    ediff-odd-diff-A
    ediff-odd-diff-B
    ediff-odd-diff-C
    ediff-odd-diff-Ancestor)
  "Diff faces whose backgrounds should be softened.")

(defvar scott/diff-soften-background-cache (make-hash-table :test 'equal)
  "Theme-specific source backgrounds for `scott/diff-soften-faces'.")

(defun scott/diff-soften--color-p (value)
  "Return non-nil when VALUE names a displayable color."
  (and (stringp value)
       (condition-case nil
           (color-name-to-rgb value)
         (error nil))))

(defun scott/diff-soften--theme-background (face)
  "Return FACE's background from an enabled theme, if available."
  (when (fboundp 'doom-theme-face-attribute)
    (cl-loop for theme in custom-enabled-themes
             for background = (unless (eq theme 'user)
                                (doom-theme-face-attribute theme face :background t))
             when (scott/diff-soften--color-p background)
             return background)))

(defun scott/diff-soften--source-background (face)
  "Return FACE's unsoftened background for the current theme set."
  (or
   (scott/diff-soften--theme-background face)
   (let* ((key (cons face (copy-sequence custom-enabled-themes)))
          (missing (make-symbol "missing"))
          (cached (gethash key scott/diff-soften-background-cache missing)))
     (if (eq cached missing)
         (let ((background (and (facep face) (face-background face nil t))))
           (when (scott/diff-soften--color-p background)
             (puthash key background scott/diff-soften-background-cache))
           background)
       cached))))

(defun scott/diff-soften--blend (foreground background)
  "Blend FOREGROUND toward BACKGROUND."
  (apply #'color-rgb-to-hex
         (append
          (cl-mapcar
           (lambda (fg bg)
             (+ (* (- 1 scott/diff-soften-background-blend) fg)
                (* scott/diff-soften-background-blend bg)))
           (color-name-to-rgb foreground)
           (color-name-to-rgb background))
          '(2))))

(defun scott/diff-soften-faces ()
  "Soften diff backgrounds while leaving foregrounds unspecified."
  (when custom-enabled-themes
    (let ((default-background (scott/diff-soften--source-background 'default))
          (specs nil))
      (when (scott/diff-soften--color-p default-background)
        (dolist (face scott/diff-soften-faces)
          (when-let ((background (scott/diff-soften--source-background face)))
            (when (scott/diff-soften--color-p background)
              (push `(,face ((t :background
                               ,(scott/diff-soften--blend
                                 background
                                 default-background)
                               :foreground unspecified)))
                    specs))))
        (when specs
          (apply #'custom-theme-set-faces 'user (nreverse specs)))))))

(add-hook 'doom-load-theme-hook #'scott/diff-soften-faces)
(with-eval-after-load 'magit-diff
  (scott/diff-soften-faces))
(with-eval-after-load 'ediff-diff
  (scott/diff-soften-faces))
(scott/diff-soften-faces)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

(let* ((scott/xdg-config-home (or (getenv "XDG_CONFIG_HOME")
                                  (expand-file-name "~/.config")))
       (doom-local-options (expand-file-name "doom-local/options.el"
                                             scott/xdg-config-home)))
  (when (file-readable-p doom-local-options)
    (load doom-local-options nil 'nomessage)))

(load! "modules/org")
(load! "modules/caldav")
(load! "modules/benedict")
(load! "modules/muster")


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `after!' block, otherwise Doom's defaults may override your settings. E.g.
;;
;;   (after! PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look up their documentation).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.

(defun scott/open-repo-status-for-client ()
  (when (eq (window-buffer) (doom-fallback-buffer))
    (when-let* ((directory (getenv "PWD" (selected-frame)))
                ((locate-dominating-file directory ".git")))
      (magit-status directory))))

(add-hook 'server-after-make-frame-hook #'scott/open-repo-status-for-client)

(use-package! dimmer
  :init
  (setq dimmer-fraction 0.5)
  :config
  (dimmer-configure-magit)
  (dimmer-configure-which-key)
  (dimmer-mode 1))

(add-to-list 'initial-frame-alist '(fullscreen . maximized))
(after! doom-cli-env
  (add-to-list 'doom-env-allow "^SSH_AUTH_SOCK$"))



(use-package! majutsu
  :defer t
  :init
  (map! :leader
        (:prefix ("j" . "jujutsu")
         :desc "Status" "j" #'majutsu-log
         :desc "Status" "g" #'majutsu-log
         :desc "Dispatch" "/" #'majutsu-dispatch
         :desc "Diff transient" "." #'majutsu-diff
         :desc "Bookmarks" "b" #'majutsu-bookmark
         :desc "Annotate" "B" #'majutsu-annotate-addition
         :desc "Clone" "C" #'majutsu-git-clone-transient
         :desc "Fetch" "F" #'majutsu-git-fetch-transient
         :desc "Log options" "L" #'majutsu-log-transient
         :desc "Diff dwim" "d" #'majutsu-diff-dwim
         :desc "Diff" "D" #'majutsu-diff
         :desc "Rebase" "r" #'majutsu-rebase
         :desc "Squash" "s" #'majutsu-squash
         :desc "Split" "S" #'majutsu-split
         :desc "Restore" "R" #'majutsu-restore
         :desc "Revert" "V" #'majutsu-revert
         :desc "Absorb" "a" #'majutsu-absorb
         :desc "New change" "n" #'majutsu-new
         :desc "Metaedit" "m" #'majutsu-metaedit
         :desc "Tags" "t" #'majutsu-tag
         :desc "Workspaces" "w" #'majutsu-workspace
         :desc "Duplicate" "y" #'majutsu-duplicate
         :desc "Undo" "u" #'majutsu-undo
         :desc "Redo" "U" #'majutsu-redo
         (:prefix ("f" . "files")
          :desc "Find file" "f" #'majutsu-find-file
          :desc "Find file other window" "F" #'majutsu-find-file-other-window
          :desc "List files" "l" #'majutsu-file-list))))

(use-package! agent-shell
  :defer t
  :init
  (map! :leader
        (:prefix ("k" . "agent-shell")
         :desc "Agent shell"           "k" #'agent-shell
         :desc "New shell"             "n" #'agent-shell-new-shell
         :desc "Toggle shell"          "t" #'agent-shell-toggle
         :desc "Send region/error"     "s" #'agent-shell-send-dwim
         :desc "Send region"           "r" #'agent-shell-send-region
         :desc "Send file"             "f" #'agent-shell-send-current-file
         :desc "Send screenshot"       "S" #'agent-shell-send-screenshot
         :desc "Interrupt"             "c" #'agent-shell-interrupt
         :desc "Compose prompt"        "p" #'agent-shell-prompt-compose
         :desc "View traffic"          "l" #'agent-shell-view-traffic
         :desc "Claude Code"           "C" #'agent-shell-anthropic-start-claude-code
         :desc "oh-my-pi"              "o" #'agent-shell-omp-start-agent))
  :config
  ;; Define oh-my-pi (omp) agent config
  (defun agent-shell-omp-make-config ()
    (agent-shell-make-agent-config
     :identifier 'omp
     :mode-line-name "omp"
     :buffer-name "omp"
     :shell-prompt "omp> "
     :shell-prompt-regexp "omp> "
     :client-maker (lambda (buffer)
                     (agent-shell--make-acp-client
                      :command "omp"
                      :command-params '("--mode" "acp" "--no-session")
                      :environment-variables nil
                      :context-buffer buffer))
     :install-instructions "npm install -g @oh-my-pi/pi-coding-agent"))

  (add-to-list 'agent-shell-agent-configs (agent-shell-omp-make-config))

  ;; Define start command for omp
  (defun agent-shell-omp-start-agent ()
    "Start an oh-my-pi agent shell."
    (interactive)
    (agent-shell--dwim :config (agent-shell-omp-make-config)
                       :new-shell t)))

(setq xterm-extra-capabilities '(getSelection setSelection modifyOtherKeys))

(setq read-process-output-max (* 1024 1024))

(after! vterm
  (setq vterm-timer-delay 0.01
        vterm-max-scrollback 10000)
  (add-hook 'vterm-mode-hook
            (lambda ()
              (setq-local display-line-numbers nil)
              (when (bound-and-true-p hl-line-mode)
                (hl-line-mode -1)))))

;; Transient windows (which-key, the minibuffer, popups) shrink and regrow the
;; vterm window, and every window-configuration change propagates that size to
;; the vterm pty via `window--adjust-process-windows' ->
;; `vterm--window-adjust-process-window-size'.  Each propagation redraws the
;; terminal and SIGWINCHes the shell, which is the scroll bounce.  Debounce it:
;; resize the pty only once the layout has settled and only when the size
;; really differs from what the shell already sees.  While a transient window
;; is up, the extra terminal rows are simply hidden instead of being reflowed.
(defvar my-vterm-resize-delay 0.5
  "Seconds of window-layout quiet before a vterm pty is resized.")

(defvar-local my-vterm--resize-timer nil)
(defvar-local my-vterm--last-pty-size nil)

(defun my-vterm--resize-settled (buffer)
  "Resize the pty of vterm BUFFER once its window layout has settled."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (setq my-vterm--resize-timer nil)
      (let ((window (get-buffer-window buffer)))
        (cond
         ((or (not vterm--term)
              (not (process-live-p vterm--process))
              vterm-copy-mode
              (not window)))
         ((not (eq (window-buffer) (current-buffer)))
          ;; The vterm window is currently squeezed by something transient;
          ;; retry after the delay rather than chasing every resize.
          (setq my-vterm--resize-timer
                (run-with-idle-timer my-vterm-resize-delay nil
                                     #'my-vterm--resize-settled buffer)))
         ((let* ((size (window-adjust-process-window-size-smallest
                        vterm--process
                        (list (get-buffer-window buffer t))))
                 (width (and size (max (- (car size) (vterm--get-margin-width))
                                       vterm-min-window-width)))
                 (height (cdr size)))
            (when (and size (> height 0) (> width 0)
                       (not (equal (cons height width) my-vterm--last-pty-size)))
              (setq my-vterm--last-pty-size (cons height width))
              (let ((inhibit-read-only t))
                (vterm--set-size vterm--term height width))
              (set-process-window-size vterm--process height width)))))))))

(defun my-vterm--defer-resize (process _windows)
  "Defer pty resizes for PROCESS until the window layout settles."
  (when my-vterm--resize-timer
    (cancel-timer my-vterm--resize-timer))
  (setq my-vterm--resize-timer
        (run-with-idle-timer my-vterm-resize-delay nil
                             #'my-vterm--resize-settled (process-buffer process)))
  nil)

;; vterm registers `vterm--window-adjust-process-window-size' as its
;; process's `adjust-window-size-function', which Emacs consults on every
;; window-configuration change; replace it with the debounced version.
(add-hook 'vterm-mode-hook
          (lambda ()
            (process-put vterm--process 'adjust-window-size-function
                         #'my-vterm--defer-resize)))
