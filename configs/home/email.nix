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
  davMailIngenicoConf = pkgs.writeText "davmail-ingenico.propertries" ''
      davmail.server=true
      davmail.mode=O365Modern
      davmail.oauth.clientId=8ed87c30-ae92-4443-8528-f6a52ac95362
      davmail.oauth.redirectUri=https://login.microsoftonline.com/common/oauth2/nativeclient
      davmail.oauth.tenantId=143a5e19-140b-4632-b3ea-e71a15cddb8c
      davmail.url=https://outlook.office365.com/EWS/Exchange.asmx
      davmail.caldavPort=2080
      davmail.imapPort=2143
      davmail.ldapPort=2389
      davmail.popPort=2110
      davmail.smtpPort=2025
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
  systemd.user.services = {
    davmail-ingenico = {
      Unit = {
        Description = "DavMail Ingenico Exchange";
      };

      Service = {
        Type = "simple";
        RemainAfterExit = "no";
        ExecStart = "${pkgs.davmail}/bin/davmail ${davMailIngenicoConf}";
      };
    };
  };
}
