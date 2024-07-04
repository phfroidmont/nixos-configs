(setq
 projectile-project-search-path '("~/Projects/")
 doom-theme 'doom-gruvbox
 doom-font (font-spec :family "MesloLGS Nerd Font Mono" :size 10.0)
 doom-big-font (font-spec :family "MesloLGS Nerd Font Mono" :size 20.0)
 treemacs-git-mode 'extended
 org-directory "~/Nextcloud/Org/"
 org-roam-directory "~/Nextcloud/OrgRoam/"
 nerd-icons-font-names '("SymbolsNerdFontMono-Regular.ttf"))

                                        ; Workaround for "Error running timer: (void-function consult--ripgrep-builder)"
(use-package! consult
  :config
  (defun consult--ripgrep-builder (&rest args) (apply (consult--ripgrep-make-builder) args)))

(use-package! lsp-tailwindcss
  :init
  (setq lsp-tailwindcss-add-on-mode t)
  (setq lsp-tailwindcss-major-modes '(rjsx-mode web-mode html-mode css-mode typescript-mode typescript-tsx-mode tsx-ts-mode ;; scala-mode
                                      ))
  (setq lsp-tailwindcss-experimental-class-regex [
                                                  [ "cls\\(([^)]*)\\)" "\"([^']*)\"" ]
                                                  [ "cls\\s*:=\\s*\\(?([^,^\\n^\\)]*)" "\"([^']*)\"" ]]))

(with-eval-after-load 'lsp-mode
  (add-to-list 'lsp-file-watch-ignored-directories "[/\\\\]node_modules\\'")
  (add-to-list 'lsp-file-watch-ignored-directories "[/\\\\]\\.cache\\'")
  (add-to-list 'lsp-file-watch-ignored-directories "[/\\\\]\\.direnv\\'")
  (add-to-list 'lsp-file-watch-ignored-directories "[/\\\\]\\.devenv\\'")
  (add-to-list 'lsp-file-watch-ignored-directories "[/\\\\]\\.metals\\'")
  (add-to-list 'lsp-file-watch-ignored-directories "[/\\\\]\\.bloop\\'")
  (add-to-list 'lsp-file-watch-ignored-directories "[/\\\\]out\\'"))

(after! nix-mode
  (set-formatter! 'nixpkgs-fmt '("nixpkgs-fmt" ) :modes '(nix-mode)))

(use-package! websocket
  :after org-roam)

(use-package! org-roam-ui
  :after org-roam ;; or :after org
  ;;         normally we'd recommend hooking orui after org-roam, but since org-roam does not have
  ;;         a hookable mode anymore, you're advised to pick something yourself
  ;;         if you don't care about startup time, use
  ;;  :hook (after-init . org-roam-ui-mode)
  :config
  (setq org-roam-ui-sync-theme t
        org-roam-ui-follow t
        org-roam-ui-update-on-save t
        org-roam-ui-open-on-start t))

                                        ; Taken from https://github.com/yqrashawn/yqdotfiles/blob/master/.doom.d/read.el
(setq! elfeed-use-curl t)
(after! elfeed
  (elfeed-set-timeout 36000)
  (run-with-idle-timer 300 t #'elfeed-update)
  (setq!
   elfeed-search-filter "+unread"
   rmh-elfeed-org-files `(,(concat org-directory "elfeed.org"))
   elfeed-protocol-feeds '(("owncloud+https://paultrial@cloud.banditlair.com"
                            :password (shell-command-to-string "echo -n `secret-tool lookup elfeed nextcloud`"))))
  (add-hook! 'elfeed-search-mode-hook 'elfeed-update)
  (setq elfeed-protocol-enabled-protocols '(owncloud))
  (elfeed-protocol-enable))

(use-package! elfeed-tube
  :after elfeed
  :demand t
  :config
  ;; (setq elfeed-tube-auto-save-p nil) ; default value
  ;; (setq elfeed-tube-auto-fetch-p t)  ; default value
  (elfeed-tube-setup)

  :bind (:map elfeed-show-mode-map
         ("F" . elfeed-tube-fetch)
         ([remap save-buffer] . elfeed-tube-save)
         :map elfeed-search-mode-map
         ("F" . elfeed-tube-fetch)
         ([remap save-buffer] . elfeed-tube-save)))

(use-package! elfeed-tube-mpv
  :bind (:map elfeed-show-mode-map
              ;; ("gf" . elfeed-tube-mpv-follow-mode)
              ;; ("gw" . elfeed-tube-mpv-where)))
              ))

;; Force using LSP formatter until this is resolved: https://github.com/doomemacs/doomemacs/issues/7490
(setq-hook! 'scala-mode-hook
  apheleia-inhibit t
  +format-with nil)
(add-hook 'scala-mode-hook
          (lambda()
            (add-hook 'before-save-hook #'lsp-format-buffer t t)
            (add-hook 'before-save-hook #'lsp-organize-imports t t)))
