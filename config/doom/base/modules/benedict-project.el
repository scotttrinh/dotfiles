;;; modules/benedict-project.el -*- lexical-binding: t; -*-

;; A `project-find-files' tool for Benedict sessions, defined here in the
;; personal config rather than upstream in the benedict checkout.
;;
;; `benedict-deftool' is just sugar over `benedict-tool-create' plus
;; `benedict-tool-register', so defining a tool here is no different from
;; defining one in ext/.  The tool is registered as a side effect of
;; loading this file, which `scott/benedict--load' does by path -- this
;; directory is not on `load-path', so `require' would not find it.

(require 'cl-lib)
(require 'seq)
(require 'projectile)
(require 'benedict)
(require 'benedict-tool)

(defconst scott/benedict-project-find-files-max-default 100
  "Default cap on how many files `project-find-files' returns.")

(defun scott/benedict-project--root ()
  "Return the current projectile project root, or nil."
  (condition-case nil
      (projectile-project-root)
    (error nil)))

(defun scott/benedict-project--normalize-extensions (extensions)
  "Return EXTENSIONS as a list of strings without leading dots.

EXTENSIONS may be a vector (as decoded from JSON) or a list.  Each
element is downcased and stripped of any leading dot, so the strings
\".el\" and \"el\" both match files ending in .el.  Returns nil when
EXTENSIONS is nil or empty."
  (let ((list (if (vectorp extensions) (append extensions nil) extensions)))
    (when list
      (delq nil
            (mapcar (lambda (ext)
                      (let ((s (string-trim (downcase (string-trim (or ext ""))))))
                        (unless (string-empty-p s)
                          (string-trim-left s "\\."))))
                    list)))))

(defun scott/benedict-project--matches (file subpath extensions)
  "Return non-nil when FILE (relative to the project root) matches.

SUBPATH, when non-nil, must be a prefix of FILE.  EXTENSIONS, when
non-nil, is a list of extensions (without dots) any of which FILE's
extension must equal."
  (and (or (null subpath) (string-prefix-p subpath file))
       (or (null extensions)
           (let ((ext (file-name-extension file)))
             (and ext (member (downcase ext) extensions))))))

(defun scott/benedict-project--handler (invocation)
  "List files in the current projectile project for INVOCATION.

Reads the `subpath', `extensions', and `max' arguments.  Returns a
`benedict-tool-result' whose content lists the matching files, one per
line, prefixed by the project root and a count.  Returns an error result
when there is no projectile project."
  (let* ((subpath (benedict-tool-arg invocation :subpath))
         (extensions (benedict-tool-arg invocation :extensions))
         (max (or (benedict-tool-arg invocation :max)
                  scott/benedict-project-find-files-max-default))
         (root (scott/benedict-project--root)))
    (if (null root)
        (benedict-tool-result-error
         "No projectile project here.  Open a file inside a project first.")
      (let* ((ext-list (scott/benedict-project--normalize-extensions extensions))
             (files (seq-filter
                     (lambda (f) (scott/benedict-project--matches f subpath ext-list))
                     (projectile-project-files root)))
             (shown (seq-take files max)))
        (benedict-tool-result
         :content
         (format "Project: %s\nFiles: %d%s\n%s"
                 root
                 (length files)
                 (if (> (length files) max)
                     (format " (showing first %d)" max)
                   "")
                 (mapconcat #'identity shown "\n")))))))

(benedict-deftool project-find-files
  :label "Find Project Files"
  :description "List files in the current projectile project, relative to its root.\n\nUseful for understanding the structure of the project you are running in.\n\n- `subpath': only list files under this directory prefix (e.g. \"src\" or \"config/doom\").\n- `extensions': only list files with one of these extensions, without dots (e.g. [\"el\" \"nix\"]).\n- `max': maximum number of files to return (default 100).\n\nReturns the project root, the total matching count, and the file list, one per line."
  :parameters '((subpath :type string :description "Only list files under this directory prefix.")
                (extensions :type array :items (:type string) :description "Only list files with these extensions, without dots.")
                (max :type integer :description "Maximum number of files to return (default 100)."))
  :sync t
  :handler #'scott/benedict-project--handler)

(provide 'benedict-project)
;;; modules/benedict-project.el ends here
