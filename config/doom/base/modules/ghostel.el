;;; modules/ghostel.el -*- lexical-binding: t; -*-

(defvar +ghostel--id nil)

(use-package! ghostel
  :commands (ghostel ghostel-project ghostel-create)
  :init
  ;; Auto-download pre-built binary without prompting
  (setq ghostel-module-auto-install 'download)
  :hook ((ghostel-mode . doom-disable-line-numbers-h)
         (ghostel-mode . mode-line-invisible-mode))
  :config
  ;; Bottom popup window matching Doom's standard popup terminal behavior
  (set-popup-rule! "^\\*doom:ghostel-popup" :size 0.25 :vslot -4 :select t :quit nil :ttl 0)

  (setq-hook! 'ghostel-mode-hook
    ;; Don't prompt about dying processes when killing buffer
    confirm-kill-processes nil
    ;; Prevent premature horizontal scrolling
    hscroll-margin 0)

  (with-eval-after-load 'project
    (add-to-list 'project-switch-commands '(ghostel-project "Ghostel") t)))

(use-package! evil-ghostel
  :after (ghostel evil)
  :hook (ghostel-mode . evil-ghostel-mode))

(use-package! consult-ghostel
  :after (ghostel consult))

;;;###autoload
(defun +ghostel/toggle (arg)
  "Toggle a ghostel popup window at project root.

If prefix ARG is non-nil, recreate ghostel buffer in `default-directory'."
  (interactive "P")
  (require 'ghostel)
  (let* ((project-root (or (doom-project-root) default-directory))
         (default-directory (if arg default-directory project-root))
         (buffer-name
          (format "*doom:ghostel-popup:%s*"
                  (if (bound-and-true-p persp-mode)
                      (safe-persp-name (get-current-persp))
                    "main"))))
    (when arg
      (when-let* ((buffer (get-buffer buffer-name)))
        (when (buffer-live-p buffer)
          (kill-buffer buffer)))
      (when-let* ((window (get-buffer-window buffer-name)))
        (when (window-live-p window)
          (delete-window window))))
    (if-let* ((win (get-buffer-window buffer-name)))
        (delete-window win)
      (let ((buffer (or (cl-loop for buf in (buffer-list)
                                 if (and (equal (buffer-name buf) buffer-name)
                                         (buffer-live-p buf))
                                 return buf)
                        (let ((default-directory (if arg default-directory project-root)))
                          (ghostel-create buffer-name)))))
        (with-current-buffer buffer
          (setq-local +ghostel--id buffer-name))
        (pop-to-buffer buffer)))))

;;;###autoload
(defun +ghostel/here (arg)
  "Open a ghostel terminal in the current window.

If prefix ARG is non-nil, cd into `default-directory' instead of project root."
  (interactive "P")
  (require 'ghostel)
  (let ((default-directory (if arg default-directory (or (doom-project-root) default-directory))))
    (ghostel t)))

(map! :leader
      (:prefix ("o" . "open")
       :desc "Toggle ghostel popup" "t" #'+ghostel/toggle
       :desc "Open ghostel here"    "T" #'+ghostel/here)
      (:prefix-map ("p" . "project")
       :desc "Ghostel in project"   "t" #'ghostel-project))

;;; ghostel.el ends here
