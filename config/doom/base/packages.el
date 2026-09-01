;; -*- no-byte-compile: t; -*-
;;; $DOOMDIR/packages.el

;; To install a package:
;;
;;   1. Declare them here in a `package!' statement,
;;   2. Run 'doom sync' in the shell,
;;   3. Restart Emacs.
;;
;; Use 'C-h f package\!' to look up documentation for the `package!' macro.


;; To install SOME-PACKAGE from MELPA, ELPA or emacsmirror:
;; (package! some-package)

;; To install a package directly from a remote git repo, you must specify a
;; `:recipe'. You'll find documentation on what `:recipe' accepts here:
;; https://github.com/radian-software/straight.el#the-recipe-format
;; (package! another-package
;;   :recipe (:host github :repo "username/repo"))

;; If the package you are trying to install does not contain a PACKAGENAME.el
;; file, or is located in a subdirectory of the repo, you'll need to specify
;; `:files' in the `:recipe':
;; (package! this-package
;;   :recipe (:host github :repo "username/repo"
;;            :files ("some-file.el" "src/lisp/*.el")))

;; If you'd like to disable a package included with Doom, you can do so here
;; with the `:disable' property:
;; (package! builtin-package :disable t)

;; You can override the recipe of a built in package without having to specify
;; all the properties for `:recipe'. These will inherit the rest of its recipe
;; from Doom or MELPA/ELPA/Emacsmirror:
;; (package! builtin-package :recipe (:nonrecursive t))
;; (package! builtin-package-2 :recipe (:repo "myfork/package"))

;; Specify a `:branch' to install a package from a particular branch or tag.
;; This is required for some packages whose default branch isn't 'master' (which
;; our package manager can't deal with; see radian-software/straight.el#279)
;; (package! builtin-package :recipe (:branch "develop"))

;; Use `:pin' to specify a particular commit to install.
;; (package! builtin-package :pin "1a2b3c4d5e")


;; Doom's packages are pinned to a specific commit and updated from release to
;; release. The `unpin!' macro allows you to unpin single packages...
;; (unpin! pinned-package)
;; ...or multiple packages
;; (unpin! pinned-package another-pinned-package)
;; ...Or *all* packages (NOT RECOMMENDED; will likely break things)
;; (unpin! t)
(package! doric-themes)
(package! majutsu :recipe (:host github :repo "0WD0/majutsu"))
(package! vui :recipe (:host github :repo "d12frosted/vui.el") :pin "9101db52a29c4276b45f85e63924008f0e41c39c") ;; 1.3.0
(package! shell-maker)
(package! acp)
(package! agent-shell)

(package! org-caldav)

;; Benedict is built from a local checkout rather than fetched from a remote.
;; Guarded on the tree existing so `doom sync' still succeeds on a machine that
;; does not have it.  Keep the path in step with `scott/benedict-root' in
;; modules/benedict.el; `package!' quotes its :recipe, so the literal cannot be
;; shared with a variable.
;;
;;   :type nil     registers no-op VC methods for clone, fetch, and
;;                 check-out-commit, so `doom upgrade' never touches a working
;;                 tree it does not own.
;;   :build        (:not compile) keeps .elc files from going stale against a
;;                 tree that is still moving.  The autoloads step still runs,
;;                 which is what puts Benedict's ;;;###autoload commands on the
;;                 leader map without declaring them by hand.
;;   :files        mandatory here.  straight's default spec globs only
;;                 top-level *.el and every Benedict source file lives in a
;;                 subdirectory; without this the package builds empty.  The
;;                 six directories flatten into one build directory safely
;;                 because Benedict keeps file name prefixes globally unique.
(when (file-directory-p (expand-file-name "~/github.com/scotttrinh/benedict"))
  (package! benedict
    :recipe (:local-repo "/Users/scotttrinh/github.com/scotttrinh/benedict"
             :type nil
             :build (:not compile)
             :files ("core/*.el" "support/*.el" "api/*.el"
                     "providers/*.el" "ext/*.el" "ui/*.el"))))

;; Muster: CLI/TUI coding agents in projectile projects (event-driven).
(when (file-directory-p (expand-file-name "~/github.com/scotttrinh/shepherd"))
  (package! muster
    :recipe (:local-repo "/Users/scotttrinh/github.com/scotttrinh/shepherd"
             :type nil
             :build (:not compile)
             :files ("*.el"))))

