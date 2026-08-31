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

(map! :leader
      (:prefix ("n" . "notes")
       :desc "Today's daily" "d" #'scott/org-today))

(after! org
  (setq org-default-notes-file (expand-file-name "inbox.org" org-directory)
        org-agenda-files (or (scott/org-files-under-directory org-directory)
                             (list org-default-notes-file))))
