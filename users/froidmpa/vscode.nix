{ config, lib, pkgs, ... }:
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscodium;
    extensions = (
      with pkgs.vscode-extensions; [
        pkief.material-icon-theme
        jnoortheen.nix-ide
        arrterian.nix-env-selector
        scala-lang.scala
        scalameta.metals
        hashicorp.terraform
        bradlc.vscode-tailwindcss
        asciidoctor.asciidoctor-vscode
      ]
    );
    userSettings = {
      "editor.formatOnSave" = true;
      "editor.quickSuggestions" = {
        "strings" = true;
      };
      "tailwindCSS.includeLanguages" = {
        "scala" = "html";
      };
      "tailwindCSS.experimental.classRegex" = [
        [ "cls\\(([^)]*)\\)" "\"([^']*)\"" ]
        [ "cls\\s*:=\\s*\\(?([^,^\\n^\\)]*)" "\"([^']*)\"" ]
      ];

      "files.autoSave" = "onFocusChange";
      "files.watcherExclude" = {
        "**/.bloop" = true;
        "**/.metals" = true;
        "**/.ammonite" = true;
      };
      "gruvboxMaterial.darkContrast" = "hard";
      "metals.millScript" = "mill";
      "nix.enableLanguageServer" = true;
      "terminal.integrated.confirmOnExit" = "hasChildProcesses";
      "terraform.languageServer" = {
        "external" = true;
        "pathToBinary" = "";
        "args" = [
          "serve"
        ];
        "maxNumberOfProblems" = 100;
        "trace.server" = "off";
      };
      "workbench.colorTheme" = "Gruvbox Material Dark";
      "workbench.iconTheme" = "material-icon-theme";
      "asciidoc.use_kroki" = true;
      "explorer.confirmDelete" = false;
      "explorer.confirmDragAndDrop" = false;
      "terminal.integrated.shellIntegration.enabled" = false;
      "terminal.external.linuxExec" = "alacritty";
      "terminal.integrated.scrollback" = 65535;
    };
  };
}
