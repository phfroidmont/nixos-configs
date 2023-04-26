(setq
 projectile-project-search-path '("~/Projects/")
 doom-theme 'doom-gruvbox
 doom-font (font-spec :family "MesloLGS Nerd Font Mono" :size 16)
 doom-big-font (font-spec :family "MesloLGS Nerd Font Mono" :size 24)
 treemacs-git-mode 'extended
 org-directory "~/Nextcloud/Org/"
 org-roam-directory "~/Nextcloud/OrgRoam/")

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

;; Update elfeed on open
(add-hook 'elfeed-search-mode-hook #'elfeed-update)

(use-package! elfeed-tube
  ;;:ensure t ;; or :straight t
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
  ;;:ensure t ;; or :straight t
  :bind (:map elfeed-show-mode-map
              ("gf" . elfeed-tube-mpv-follow-mode)
              ("gw" . elfeed-tube-mpv-where)))
