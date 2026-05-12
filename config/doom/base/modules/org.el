;;; modules/org.el -*- lexical-binding: t; -*-

(defvar scott/doom-org-directory (expand-file-name "~/org"))

(setq org-directory (file-name-as-directory (expand-file-name scott/doom-org-directory)))

(defun scott/org-files-under-directory (directory)
  "Return Org files under DIRECTORY when it exists."
  (when (file-directory-p directory)
    (directory-files-recursively directory "\\.org\\'")))

(after! org
  (setq org-default-notes-file (expand-file-name "inbox.org" org-directory)
        org-agenda-files (or (scott/org-files-under-directory org-directory)
                             (list org-default-notes-file))))
