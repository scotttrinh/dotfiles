;;; modules/muster.el -*- lexical-binding: t; -*-

;; Muster runs CLI/TUI coding agents (codex, fx, claude) in projectile-managed
;; projects inside vterm, tracking lifecycle events via side channels.

(map! :leader
      (:prefix ("m" . "muster")
       :desc "Herd (roll call)"      "m" #'muster-herd
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
  (muster-mode 1))
