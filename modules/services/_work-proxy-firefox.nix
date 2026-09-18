{ pkgs }:

let
  customCaBundle = pkgs.runCommand "ca-bundle-with-foyer.crt" { } ''
    cat ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt \
        ${./certs/Foyer-Group-Root-CA.crt} \
        ${./certs/Foyer-Sub-CA.crt} > $out
  '';
  extension = pkgs.fetchurl {
    name = "foyer-impersonation-firefox-extension-2.0.2.xpi";
    url = "https://github.foyer.lu/platform/foyer-impersonation-browser-extension/releases/download/v2.0.2/foyer-impersonation-firefox-extension-2.0.2.zip";
    sha256 = "1adcbaadb5c70d4727b18798167896614823519b3953828382a3e065840717f8";
    curlOptsList = [
      "--cacert"
      "${customCaBundle}"
    ];
  };
in
{
  # This must be set before mozilla.cfg runs so the loader can use privileged APIs.
  extraAutoConfig = ''
    pref("general.config.sandbox_enabled", false);
  '';
  extraPrefsFiles = [
    (pkgs.replaceVars ./work-proxy-firefox.js {
      extensionPath = extension;
    })
  ];
}
