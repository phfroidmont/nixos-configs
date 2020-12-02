{ config, lib, pkgs, ... }:
let
  davMailArhsConf = pkgs.writeText "davmail-arhs.propertries" ''
    davmail.server=true
    davmail.url=https\://webmail.arhs-developments.com/owa/
    davmail.caldavPort=1080
    davmail.imapPort=1143
    davmail.ldapPort=1389
    davmail.popPort=1110
    davmail.smtpPort=1025
    davmail.disableUpdateCheck=true
  '';
in {
  home.packages = with pkgs; [
    davmail
  ];
  systemd.user.services = {
    davmail-arhs = {
      Unit = {
        Description = "DavMail ARhS Exchange";
      };

      Service = {
        Type = "simple";
        RemainAfterExit = "no";
        ExecStart = "${pkgs.davmail}/bin/davmail ${davMailArhsConf}";
      };
    };
  };
}
