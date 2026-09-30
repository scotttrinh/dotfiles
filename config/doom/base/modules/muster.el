;;; modules/muster.el -*- lexical-binding: t; -*-

;; Muster presents Projectile's known projects and their Git worktrees in a
;; persistent persp-mode sidebar.  Agent TUIs run in Ghostel buffers attached
;; to the Doom workspace for their concrete checkout.

(map! :leader
      (:prefix ("m" . "muster")
       :desc "Project sidebar"       "m" #'muster-sidebar-toggle
       :desc "Project sidebar"       "b" #'muster-sidebar-toggle
       :desc "Herd (roll call)"      "h" #'muster-herd
       :desc "Next attention"        "n" #'muster-next-attention
       :desc "Spawn agent"           "s" #'muster-spawn-agent
       :desc "Spawn codex"           "c" (cmd! (muster-spawn-agent (if (fboundp 'projectile-project-root)
                                                                       (projectile-project-root)
                                                                     default-directory)
                                                                   'codex))
       :desc "Spawn fx"              "f" (cmd! (muster-spawn-agent (if (fboundp 'projectile-project-root)
                                                                       (projectile-project-root)
                                                                       default-directory)
                                                                   'fx))
       :desc "View ingest log"       "l" #'muster-log))

(after! muster
  (defun scott/muster-route-codex-escape-to-evil (_agent-id harness _command)
    "Make ESC leave insert state in Muster Codex buffers.
Other harnesses retain evil-ghostel's automatic terminal routing."
    (when (and (eq harness 'codex)
               (boundp 'evil-ghostel--escape-mode))
      (setq-local evil-ghostel--escape-mode 'evil)))

  (unless (advice-member-p #'scott/muster-route-codex-escape-to-evil
                           #'muster-agent--start-ghostel)
    (advice-add #'muster-agent--start-ghostel :after
                #'scott/muster-route-codex-escape-to-evil))
  (muster-mode 1))
