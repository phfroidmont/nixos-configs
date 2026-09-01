{
  fetchurl,
  lib,
  makeWrapper,
  nodejs_24,
  runCommand,
  stdenvNoCC,
  testers,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "jellyfin-cli";
  version = "2026.8.8";

  src = fetchurl {
    url = "https://registry.npmjs.org/jellyfin-cli/-/jellyfin-cli-${finalAttrs.version}.tgz";
    hash = "sha512-fDvo3BxsSgLxeRJKvFxaZyx2omkPkGas1xmrP7bdkcKhriC/ShTwdU0OEZYW/jyhFT4ZboTzOfikRX9qLUL2IA==";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib/jellyfin-cli $out/share/licenses/jellyfin-cli
    install -m644 dist/cli.js $out/lib/jellyfin-cli/cli.js
    install -m644 LICENSE $out/share/licenses/jellyfin-cli/LICENSE

    makeWrapper ${lib.getExe nodejs_24} $out/bin/jf \
      --add-flags $out/lib/jellyfin-cli/cli.js
    ln -s jf $out/bin/jellyfin-cli
    ln -s jf $out/bin/jf-cli

    runHook postInstall
  '';

  passthru.tests.version = testers.testVersion {
    package = finalAttrs.finalPackage;
    command = "jf --version";
  };
  passthru.tests.aliases =
    runCommand "jellyfin-cli-aliases-test"
      {
        nativeBuildInputs = [ finalAttrs.finalPackage ];
      }
      ''
        jellyfin-cli --version
        jf-cli --version
        touch $out
      '';

  meta = {
    description = "Agent-optimized CLI for interacting with the Jellyfin API";
    homepage = "https://github.com/unbraind/jellyfin-cli";
    license = lib.licenses.mit;
    mainProgram = "jf";
    inherit (nodejs_24.meta) platforms;
  };
})
