;;; modules/org.el -*- lexical-binding: t; -*-

(defvar scott/doom-org-directory (expand-file-name "~/org"))

(setq org-directory (file-name-as-directory (expand-file-name scott/doom-org-directory)))

(defun scott/org-files-under-directory (directory)
  "Return Org files under DIRECTORY when it exists."
  (when (file-directory-p directory)
    (directory-files-recursively directory "\\.org\\'")))

(defun scott/org-today ()
  "Visit today's heading in the current ISO week file."
  (interactive)
  (let* ((week (format-time-string "%G-w%V"))
         (file (expand-file-name
                (format "weekly/%s__weekly_work_family.org" week)
                org-directory))
         (heading (format-time-string "%A %Y-%m-%d")))
    (unless (file-exists-p file)
      (user-error "Weekly file does not exist: %s" file))
    (find-file file)
    (goto-char (point-min))
    (unless (re-search-forward
             (format "^\\* %s[ \t]*$" (regexp-quote heading)) nil t)
      (user-error "Today's heading does not exist: %s" heading))
    (beginning-of-line)
    (org-reveal)))

(defvar scott/org-agenda-side-window-width 38
  "Width in columns for the sticky daily agenda side-window.")

(defvar scott/org-agenda-side-buffer-name "*Org Agenda(today-sidebar)*"
  "Dedicated buffer name for the daily agenda side-window.")

(defun scott/org-agenda-today-view ()
  "Generate a 1-day agenda buffer for today."
  (save-window-excursion
    (let ((org-agenda-span 'day)
          (org-agenda-use-time-grid t)
          (org-agenda-sticky t)
          (org-agenda-buffer-tmp-name scott/org-agenda-side-buffer-name)
          (org-agenda-window-setup 'current-window))
      (org-agenda-list nil (format-time-string "%Y-%m-%d") 'day)
      (setq-local org-agenda-sticky t)
      (current-buffer))))

(defun scott/org-agenda-sidebar-display (buffer)
  "Display BUFFER in a dedicated right side window without closing main windows."
  (let ((win (display-buffer-in-side-window
              buffer
              `((side . right)
                (slot . 0)
                (window-width . ,scott/org-agenda-side-window-width)
                (dedicated . t)
                (window-parameters . ((no-delete-other-windows . t)
                                      (no-other-window . nil)))))))
    (when win
      (select-window win))))

(defun scott/toggle-org-agenda-sidebar ()
  "Toggle a sticky side-window displaying today's agenda timeline."
  (interactive)
  (let ((agenda-buf (get-buffer scott/org-agenda-side-buffer-name)))
    (if (and agenda-buf (get-buffer-window agenda-buf))
        (delete-window (get-buffer-window agenda-buf))
      (let ((buf (or agenda-buf (scott/org-agenda-today-view))))
        (with-current-buffer buf
          (org-agenda-redo t))
        (scott/org-agenda-sidebar-display buf)))))

(map! :leader
      (:prefix ("n" . "notes")
       :desc "Today's daily" "d" #'scott/org-today)
      (:prefix ("o" . "open")
       (:prefix ("a" . "org agenda")
        :desc "Today sidebar" "s" #'scott/toggle-org-agenda-sidebar)))

(after! org
  (setq org-default-notes-file (expand-file-name "inbox.org" org-directory)
        org-agenda-files (or (scott/org-files-under-directory org-directory)
                             (list org-default-notes-file))))

(after! org-agenda
  ;; Ignore popup rules for our dedicated side-window buffer so Doom's popup
  ;; manager doesn't intercept it or tear down other windows.
  (set-popup-rule! (format "^%s" (regexp-quote scott/org-agenda-side-buffer-name))
    :ignore t)

  (setq org-agenda-use-time-grid t
        org-agenda-current-time-string "NOW --------------------------------"
        org-agenda-time-grid
        '((daily today require-timed)
          (800 1000 1200 1400 1600 1800 2000)
          "......" "----------------")))

