{
  pkgs,
  lib,
  buildGo126Module,
  fetchFromGitHub,
  makeWrapper,
  testers,
  xdg-utils,
}:
let
  customCaBundle = pkgs.runCommand "ca-bundle-with-foyer.crt" { } ''
    cat ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt \
        ${../../modules/services/certs/Foyer-Group-Root-CA.crt} \
        ${../../modules/services/certs/Foyer-Sub-CA.crt} > $out
  '';
in
buildGo126Module (finalAttrs: {
  pname = "get-token";
  version = "0.2.1";

  src = fetchFromGitHub {
    githubBase = "github.foyer.lu";
    owner = "platform";
    repo = "get-token";
    rev = "83fc7703337aa08f097f1bf9aecafe81d2aaef08";
    hash = "sha256-1r42DPJKSEAecaANw5sXPhZaVVIyAxh+KsAEOa/DoIQ=";
    curlOptsList = [
      "--location"
      "--cacert"
      "${customCaBundle}"
    ];
  };

  vendorHash = "sha256-9jK3jKbFp+5WSQfMbNzwIB55bC5KScZOaFHItffTF00=";

  env.CGO_ENABLED = 0;

  ldflags = [
    "-s"
    "-w"
    "-X github.foyer.lu/platform/get-token/internal/build.Version=${finalAttrs.version}"
    "-X github.foyer.lu/platform/get-token/internal/build.Commit=83fc770"
    "-X github.foyer.lu/platform/get-token/internal/build.Date=2026-06-24T17:27:04Z"
  ];

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram $out/bin/get-token \
      --prefix PATH : ${lib.makeBinPath [ xdg-utils ]}
  '';

  passthru.tests.version = testers.testVersion {
    package = finalAttrs.finalPackage;
    command = "get-token --version";
    inherit (finalAttrs) version;
  };

  meta = {
    description = "Dev-only CLI that mints short-lived JWTs for Foyer APIs";
    homepage = "https://github.foyer.lu/platform/get-token";
    license = lib.licenses.mit;
    mainProgram = "get-token";
    platforms = lib.platforms.unix;
  };
})
