;;; modules/caldav.el -*- lexical-binding: t; -*-

(defvar scott/doom-caldav-enabled nil)

(when scott/doom-caldav-enabled
  (use-package! org-caldav
    :after org
    :commands (org-caldav-sync org-caldav-delete-everything)
    :init
    (defun scott/org-caldav-sync ()
      "Sync the configured Fastmail calendars."
      (interactive)
      (require 'org-caldav)
      (make-directory org-caldav-save-directory t)
      (org-caldav-sync))

    (map! :leader
          (:prefix ("o c" . "calendar")
           :desc "Sync CalDAV" "s" #'scott/org-caldav-sync
           :desc "Delete CalDAV entries" "d" #'org-caldav-delete-everything))
    :config
    (require 'auth-source)
    (require 'url-auth)

    ;; Emacs URL auth looks up HTTPS credentials as HOST:443 + "https",
    ;; while authinfo conventionally stores HOST + 443. Normalize only the
    ;; Fastmail lookup so org-caldav can use the existing SOPS-managed entry.
    (define-advice url-do-auth-source-search
        (:around (original server type parameter) scott/fastmail-authinfo-port)
      (or (funcall original server type parameter)
          (when (and (equal server "caldav.fastmail.com:443")
                     (equal type "https"))
            (let* ((credentials
                    (car (auth-source-search :host "caldav.fastmail.com"
                                             :port 443
                                             :max 1)))
                   (value (plist-get credentials parameter)))
              (if (functionp value) (funcall value) value)))))

    (let* ((credentials
            (car (auth-source-search :host "caldav.fastmail.com"
                                     :port 443
                                     :require '(:user)
                                     :max 1)))
           (user (plist-get credentials :user)))
      (unless user
        (user-error "No caldav.fastmail.com login found in auth-sources"))
      (setq org-caldav-url
            (format "https://caldav.fastmail.com/dav/calendars/user/%s/" user)))

    (setq org-icalendar-timezone "America/New_York"
          org-icalendar-include-todo 'all
          org-caldav-sync-todo nil
          org-caldav-sync-direction 'cal->org
          org-caldav-delete-calendar-entries 'never
          org-caldav-delete-org-entries 'ask
          org-caldav-sync-changes-to-org 'title-and-timestamp
          org-caldav-files nil
          org-caldav-inbox (expand-file-name "calendar/inbox.org" org-directory)
          org-caldav-save-directory (expand-file-name ".org-caldav/" org-directory)
          org-caldav-calendars
          `((:calendar-id "61AEA560-35A8-11EC-824A-1D4387A4DFFC"
             :inbox ,(expand-file-name "calendar/fastmail-personal.org" org-directory)
             :files (,(expand-file-name "calendar/fastmail-personal.org" org-directory)))
            (:calendar-id "d955d431-af2e-47eb-a2bd-3425cc16450e"
             :inbox ,(expand-file-name "calendar/family.org" org-directory)
             :files (,(expand-file-name "calendar/family.org" org-directory)))
            (:calendar-id "a1ef4df4-530c-486e-b223-cbd210c44be4"
             :inbox ,(expand-file-name "calendar/work.org" org-directory)
             :files (,(expand-file-name "calendar/work.org" org-directory)))))))
