;;; modules/benedict.el -*- lexical-binding: t; -*-

;; Benedict comes from the `package!' recipe in packages.el, which builds a
;; local checkout rather than fetching a remote.  straight symlinks the sources
;; into its build directory instead of copying them, so edits to the working
;; tree are live and `scott/benedict-reload' is still the whole edit loop -- but
;; a NEW file in the tree is not symlinked until the next `doom sync'.
;;
;; Nothing is required at startup.  Benedict is a heavy load for something used
;; deliberately, so every `require' happens inside a command; the commands
;; themselves are reachable because straight harvests Benedict's ;;;###autoload
;; cookies into benedict-autoloads.el.
;;
;; The frontend's two dependencies come from straight as well: vui, pinned in
;; packages.el to the v1.3.0 the project requires, and markdown-mode, which the
;; :lang markdown module already provides.
;;
;; benedict-project.el is the exception: it lives next to this file rather than
;; in the checkout, so straight never sees it and it is not on `load-path'.  It
;; is loaded by path, not `require'd -- see `scott/benedict--load'.

(defvar scott/benedict-module-dir (dir!)
  "Directory this file was loaded from, where benedict-project.el also lives.

Captured at load time on purpose: `dir!' resolves against `load-file-name',
which is only bound while this file is being loaded, and a macro in a function
body does not expand until that function first runs -- by which point it would
expand against `default-directory' instead.")

(defvar scott/benedict-root "~/github.com/scotttrinh/benedict"
  "Working tree of the Benedict checkout.

Only used for reporting.  The recipe in packages.el is what actually puts
Benedict on `load-path', and it carries this path as a literal because
`package!' quotes its :recipe -- keep the two in step.")

(defvar scott/benedict-model "vercel-ai-gateway/deepseek/deepseek-v4-flash-0731"
  "Model for sessions started by `scott/benedict'.

A \"PROVIDER-ID/MODEL-ID\" string resolved through `benedict-model-resolve'.
This one is the cheap reasoning-and-tool-use model the live smoke test uses.
Others in the offline fallback catalog, all under \"vercel-ai-gateway/\":
\"openai/gpt-5\", \"anthropic/claude-sonnet-4.5\", \"alibaba/qwen3-coder\".")

(defvar scott/benedict-tools '(eval-elisp project-find-files)
  "Tools registered into sessions started by `scott/benedict'.")

(defvar scott/benedict-system-prompt
  "You are Benedict, an agent running inside a live Emacs image.  Your medium \
is Emacs Lisp: the eval-elisp tool evaluates a form in the running image, and \
anything you define takes effect immediately and is callable on your next turn."
  "System prompt for sessions started by `scott/benedict'.")

(defvar scott/benedict-libraries
  '(benedict
    benedict-session
    benedict-core
    benedict-api-stream
    benedict-api-openai-responses
    benedict-provider-vercel
    benedict-provider-fake
    benedict-eval
    benedict-chat)
  "Benedict libraries to `require', in dependency order.

Everything here comes from the checkout by way of straight, so plain `require'
finds it.  The locally defined project-find-files tool is not in this list; it
is not on `load-path' and `scott/benedict--load' loads it by path.

Three of these are required for their load-time side effects rather than for
any symbol: `benedict-core' is the reducer, and requiring it is what makes a
session actually run; `benedict-provider-vercel' registers the gateway
provider; `benedict-eval' registers the eval-elisp tool.")

(defun scott/benedict--load ()
  "Load every Benedict library and subscribe the chat renderer.

Signals a `user-error' naming `doom sync' when the package did not build,
which is what a missing or renamed checkout looks like from here.

benedict-project.el is loaded by absolute path after the requires, because
$DOOMDIR/modules is not on `load-path' and putting it there would shadow
Emacs's own libraries with the other files in this directory -- modules/org.el
ahead of `org' being the one that would really hurt.  Loading rather than
requiring also means `scott/benedict-reload' picks up edits to it for free."
  (unless (locate-library "benedict")
    (user-error "Benedict is not installed; check packages.el and run `doom sync'"))
  (mapc #'require scott/benedict-libraries)
  (load (expand-file-name "benedict-project" scott/benedict-module-dir)
        nil 'nomessage)
  ;; Subscribing is a command in Benedict rather than a load-time side effect,
  ;; so that requiring a ui/ file to reach a face does not enrol the image in
  ;; every session it holds.  Here we do want the image enrolled.  Idempotent.
  (benedict-chat-install))

(defun scott/benedict-buffers ()
  "Return the live Benedict chat buffers, most recently used first.

Safe to call before Benedict is loaded: `derived-mode-p' compares symbols, so
an image that has never seen a chat buffer simply yields nil."
  (seq-filter (lambda (buffer)
                (with-current-buffer buffer
                  (derived-mode-p 'benedict-chat-mode)))
              (buffer-list)))

(defun scott/benedict ()
  "Open a chat buffer on a new Benedict session against `scott/benedict-model'.

Spends real money.  The credential is resolved from AI_GATEWAY_API_KEY or
~/.config/benedict/auth.json.

Note that the eval-elisp tool evaluates arbitrary forms in THIS image, so the
agent can redefine anything Doom has loaded.  For driving the frontend rather
than the agent, `scott/benedict-demo' needs neither a credential nor trust.

In the buffer, \\<benedict-chat-mode-map>
\\[benedict-chat-send] sends and \\[benedict-chat-abort] aborts,
\\[benedict-chat-next-sibling] and \\[benedict-chat-previous-sibling] walk
branch siblings, and \\[benedict-chat-revert] redraws from the transcript.
Sending during a run is not an error -- the kernel queues it as steering."
  (interactive)
  (scott/benedict--load)
  (pop-to-buffer
   (benedict-chat-for-session
    (benedict-session-create :model scott/benedict-model
                             :tools scott/benedict-tools
                             :system-prompt scott/benedict-system-prompt))))

(defun scott/benedict-demo ()
  "Open a chat buffer on a scripted offline Benedict session.

Spends nothing, needs no credential, and evaluates nothing the script did not
name.  Replays a two-turn conversation through Benedict's fake provider --
reasoning, text, a tool call, its result, then a closing turn -- which is every
component row the frontend draws."
  (interactive)
  (scott/benedict--load)
  (let* ((script (benedict-provider-fake-script
                  '(((:thinking "The user wants arithmetic.  Use the tool."
                      :signature "sig")
                     (:text "Let me compute that.")
                     (:tool-call eval-elisp (:form "(+ 1 2)") :id "call_1"))
                    ((:text "The answer is **3**.")))))
         (model (benedict-provider-fake-model script :reasoning-p t))
         (session (benedict-session-create :model model
                                           :tools scott/benedict-tools
                                           :system-prompt "You are helpful.")))
    (pop-to-buffer (benedict-chat-for-session session))
    (benedict-session-submit session "What is (+ 1 2)?")
    session))

(defun scott/benedict-toggle ()
  "Hide the visible Benedict chat buffer, or show the most recent one.

With a chat buffer on screen, dismiss it with `quit-window', which restores
whatever the window showed before rather than killing the session.  With chat
buffers in the image but none displayed, show the most recently used.  With
none at all, start a new session -- so this is the only binding needed to get
to Benedict from a cold Emacs."
  (interactive)
  (let* ((buffers (scott/benedict-buffers))
         (window (car (delq nil (mapcar #'get-buffer-window buffers)))))
    (cond
     (window (quit-window nil window))
     (buffers (pop-to-buffer (car buffers)))
     (t (scott/benedict)))))

(defun scott/benedict-switch (buffer)
  "Switch to the Benedict chat BUFFER, chosen by completion.

Sessions coexist in one image, so several chat buffers can be live at once."
  (interactive
   (list (let ((buffers (scott/benedict-buffers)))
           (unless buffers
             (user-error "No Benedict chat buffers"))
           (get-buffer (completing-read "Benedict chat: "
                                        (mapcar #'buffer-name buffers)
                                        nil t)))))
  (pop-to-buffer buffer))

(defun scott/benedict-reload ()
  "Re-load every Benedict library from disk, discarding what is in the image.

The edit loop while hacking on the checkout.  straight symlinks rather than
copies, so this picks up edits to existing files with no `doom sync' -- but a
file ADDED to the tree since the last sync is not symlinked yet and will not be
found, which is the one failure that looks like a stale image but is not.

Chat buffers open across a reload keep rendering, because the renderer is
subscribed by named function and `add-hook' with a named function is idempotent
-- but a session created before the reload holds structs from the old
definitions, so start a fresh one after changing anything in core/."
  (interactive)
  (dolist (feature scott/benedict-libraries)
    (setq features (delq feature features)))
  (scott/benedict--load)
  (message "Benedict reloaded from %s" scott/benedict-root))

;; `benedict-chat-mode-map' binds `g' to `benedict-chat-revert', shadowing
;; `vui-refresh' -- whose idea of a refresh is a root re-render, which drops
;; every component row while faithfully re-emitting the content items.  Under
;; evil, normal state never reaches that binding, because `g' is a prefix.
;; Rebind to `gr' so the shadowing still holds where it matters.
;;
;; The mode's other bindings need no help: `C-c C-s' to send, `C-c C-c' to
;; abort, and `C-c C-n' / `C-c C-p' to walk branch siblings all reach the mode
;; map from evil's normal state already.
(map! :after benedict-chat
      :map benedict-chat-mode-map
      :n "gr" #'benedict-chat-revert)

;; `SPC K', next door to `SPC k' agent-shell, so the two agent tools sit
;; together.  The transcript commands are here as well as on the mode map
;; because a leader binding reaches them from the minibuffer prompt and from a
;; neighbouring window, where `C-c C-s' would go to the wrong buffer.
(map! :leader
      (:prefix ("K" . "benedict")
       :desc "Toggle chat"         "K" #'scott/benedict-toggle
       :desc "New chat"            "c" #'scott/benedict
       :desc "Switch to chat"      "o" #'scott/benedict-switch
       :desc "Demo chat (offline)" "d" #'scott/benedict-demo
       :desc "Send"                "s" #'benedict-chat-send
       :desc "Abort"               "a" #'benedict-chat-abort
       :desc "Next sibling"        "n" #'benedict-chat-next-sibling
       :desc "Previous sibling"    "p" #'benedict-chat-previous-sibling
       :desc "Redraw transcript"   "g" #'benedict-chat-revert
       :desc "Reload Benedict"     "R" #'scott/benedict-reload))
