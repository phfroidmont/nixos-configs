(setq
 projectile-project-search-path '("~/Projects/")
 doom-theme 'doom-gruvbox
 doom-font (font-spec :family "MesloLGS Nerd Font Mono" :size 16)
 doom-big-font (font-spec :family "MesloLGS Nerd Font Mono" :size 24)
 treemacs-git-mode 'extended)

;; Enable nice rendering of diagnostics like compile errors.
(use-package! flycheck
  :init (global-flycheck-mode))

(use-package! lsp-mode
  ;; Optional - enable lsp-mode automatically in scala files
  ;; You could also swap out lsp for lsp-deffered in order to defer loading
  :hook  (scala-mode . lsp)
         (lsp-mode . lsp-lens-mode)
  :config
  ;; Uncomment following section if you would like to tune lsp-mode performance according to
  ;; https://emacs-lsp.github.io/lsp-mode/page/performance/
  ;; (setq gc-cons-threshold 100000000) ;; 100mb
  ;; (setq read-process-output-max (* 1024 1024)) ;; 1mb
  ;; (setq lsp-idle-delay 0.500)
  ;; (setq lsp-log-io nil)
  ;; (setq lsp-completion-provider :capf)
  (setq lsp-prefer-flymake nil)
  ;; Makes LSP shutdown the metals server when all buffers in the project are closed.
  ;; https://emacs-lsp.github.io/lsp-mode/page/settings/mode/#lsp-keep-workspace-alive
  (setq lsp-keep-workspace-alive nil))

; Workaround for "Error running timer: (void-function consult--ripgrep-builder)"
(use-package! consult
  :config
  (defun consult--ripgrep-builder (&rest args) (apply (consult--ripgrep-make-builder) args)))

(use-package! lsp-tailwindcss
  :init
  (setq lsp-tailwindcss-add-on-mode t)
  (setq lsp-tailwindcss-major-modes '(rjsx-mode web-mode html-mode css-mode typescript-mode typescript-tsx-mode tsx-ts-mode scala-mode))
  (setq lsp-tailwindcss-experimental-class-regex [
            [ "cls\\(([^)]*)\\)" "\"([^']*)\"" ]
            [ "cls\\s*:=\\s*\\(?([^,^\\n^\\)]*)" "\"([^']*)\"" ]]))
