{
  bash,
  coreutils,
  gnugrep,
  gnused,
  lib,
  nh,
  nix,
  replaceVars,
  runCommand,
  shellcheck,
  symlinkJoin,
  writeShellApplication,
  zsh,
}:

let
  completion = replaceVars ./_fos {
    timeout = lib.getExe' coreutils "timeout";
    sed = lib.getExe gnused;
  };
  application = writeShellApplication {
    name = "fos";
    runtimeInputs = [
      coreutils
      gnugrep
      nh
      nix
    ];
    text = builtins.readFile ./fos.sh;
  };
  package = symlinkJoin {
    name = "fos";
    paths = [ application ];
    postBuild = ''
      ${lib.getExe zsh} -n ${completion}
      mkdir -p $out/share/zsh/site-functions
      ln -s ${completion} $out/share/zsh/site-functions/_fos
    '';
    meta = {
      description = "Froidmont Operating System command center";
      mainProgram = "fos";
      platforms = lib.platforms.linux;
    };
  };
  tests = runCommand "fos-tests" { nativeBuildInputs = [ bash ]; } ''
    ${lib.getExe shellcheck} ${./test.sh}
    test -x ${lib.getExe package}
    test -f ${package}/share/zsh/site-functions/_fos
    FOS_BIN=${lib.getExe package} ${lib.getExe bash} ${./test.sh}
    touch $out
  '';
in
package.overrideAttrs (oldAttrs: {
  passthru = (oldAttrs.passthru or { }) // {
    inherit tests;
  };
})
