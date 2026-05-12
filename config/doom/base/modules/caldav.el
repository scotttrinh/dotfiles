;;; modules/caldav.el -*- lexical-binding: t; -*-

(defvar scott/doom-caldav-enabled nil)
(defvar scott/doom-caldav-private-file
  (expand-file-name "doom-local/caldav.el"
                    (or (getenv "XDG_CONFIG_HOME")
                        (expand-file-name "~/.config"))))

(defvar scott/doom-caldav-url nil)
(defvar scott/doom-caldav-calendar-id nil)
(defvar scott/doom-caldav-calendars nil)
(defvar scott/doom-caldav-files nil)
(defvar scott/doom-caldav-inbox nil)
(defvar scott/doom-caldav-save-directory nil)
(defvar scott/doom-caldav-extra-settings nil)

(when (and scott/doom-caldav-enabled
           (file-readable-p scott/doom-caldav-private-file))
  (load scott/doom-caldav-private-file nil 'nomessage)

  (use-package! org-caldav
    :after org
    :commands (org-caldav-sync org-caldav-delete-everything)
    :init
    (map! :leader
          (:prefix ("o c" . "calendar")
           :desc "Sync CalDAV" "s" #'org-caldav-sync
           :desc "Delete CalDAV entries" "d" #'org-caldav-delete-everything))
    :config
    (setq org-caldav-url scott/doom-caldav-url
          org-caldav-calendar-id scott/doom-caldav-calendar-id
          org-caldav-calendars scott/doom-caldav-calendars
          org-caldav-files (or scott/doom-caldav-files org-agenda-files)
          org-caldav-inbox (or scott/doom-caldav-inbox org-default-notes-file)
          org-caldav-save-directory
          (or scott/doom-caldav-save-directory
              (expand-file-name "caldav/" org-directory)))
    (mapc (lambda (setting)
            (set (car setting) (cdr setting)))
          scott/doom-caldav-extra-settings)))
