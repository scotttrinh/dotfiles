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

(defun scott/org-file-changed-on-disk-p ()
  "Non-nil when the visited file no longer matches the buffer's record."
  (and buffer-file-name
       (if (file-exists-p buffer-file-name)
           (not (verify-visited-file-modtime (current-buffer)))
         ;; Distinguish a new file from one deleted after visiting.
         (not (null buffer-file-number)))))

(defvar scott/org-todo-reloading nil
  "Non-nil while reloading before re-applying a TODO state change.")

(defun scott/org-todo-reload-and-reapply (orig &rest args)
  "Reload a stale, clean Org buffer before applying a TODO change.
Emacs prompts on the first modification of a stale buffer, before
`org-after-todo-state-change-hook' runs, so the reload has to happen here."
  (if (or scott/org-todo-reloading
          (not (derived-mode-p 'org-mode))
          (not buffer-file-name)
          (not (file-exists-p buffer-file-name))
          (not (scott/org-file-changed-on-disk-p))
          (buffer-modified-p)       ; other unsaved edits: do not discard them
          (buffer-narrowed-p)       ; reverting would widen the buffer
          (and (org-region-active-p)
               org-loop-over-headlines-in-active-region))
      (apply orig args)
    (let (path id old-state)
      (save-excursion
        (org-back-to-heading t)
        (setq path (org-get-outline-path t)
              id (org-entry-get nil "ID")
              old-state (org-get-todo-state)))
      (condition-case err
          (progn
            ;; Fine-grain revert preserves markers and overlays, which matters
            ;; when the change came from the agenda.
            (revert-buffer-with-fine-grain t t)
            (let ((marker (or (and id (org-find-entry-with-id id))
                              (and path (org-find-olp path t)))))
              (unless marker
                (error "matching headline not found"))
              (goto-char marker)
              (unless (equal (or (org-get-todo-state) "")
                             (or old-state ""))
                (error "headline state changed on disk to %s"
                       (or (org-get-todo-state) "none")))
              (let ((scott/org-todo-reloading t))
                (apply orig args))))
        (error
         (message "Org: TODO change not applied: %s"
                  (error-message-string err)))))))

(defun scott/org-save-after-todo-change ()
  "Save the current Org buffer after a TODO state change."
  (when (and (derived-mode-p 'org-mode)
             buffer-file-name
             (buffer-modified-p))
    (if (scott/org-file-changed-on-disk-p)
        (message "Org: %s changed on disk; not saving. Revert or save manually."
                 (file-name-nondirectory buffer-file-name))
      (condition-case err
          (let ((save-silently t))
            (save-buffer))
        (error
         (message "Org: could not save %s: %s"
                  buffer-file-name (error-message-string err)))))))

(after! org
  (setq org-default-notes-file (expand-file-name "inbox.org" org-directory)
        org-agenda-files (or (scott/org-files-under-directory org-directory)
                             (list org-default-notes-file)))

  (add-hook 'org-after-todo-state-change-hook
            #'scott/org-save-after-todo-change)
  (unless (advice-member-p #'scott/org-todo-reload-and-reapply 'org-todo)
    (advice-add 'org-todo :around
                #'scott/org-todo-reload-and-reapply)))

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

