{
  dfu-util,
  gcc-arm-embedded,
  gnumake,
  lib,
  qmk,
  qmkFirmware,
  stdenv,
}:

stdenv.mkDerivation {
  pname = "voyager-firmware-azerty";
  version = "1";

  src = qmkFirmware;

  nativeBuildInputs = [
    dfu-util
    gcc-arm-embedded
    gnumake
    qmk
  ];

  postPatch = ''
    keymap_dir=keyboards/zsa/voyager/keymaps/azerty
    mkdir -p "$keymap_dir"
    cp ${./config.h} "$keymap_dir/config.h"
    cp ${./i18n.h} "$keymap_dir/i18n.h"
    cp ${./keymap.c} "$keymap_dir/keymap.c"
    cp ${./keymap.json} "$keymap_dir/keymap.json"
    cp ${./rules.mk} "$keymap_dir/rules.mk"
  '';

  buildPhase = ''
    runHook preBuild

    make zsa/voyager:azerty SKIP_GIT=1

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    install -m644 zsa_voyager_azerty.bin "$out/zsa_voyager_azerty.bin"

    runHook postInstall
  '';

  meta = {
    description = "QMK firmware for the ZSA Voyager AZERTY keymap";
    homepage = "https://www.zsa.io/voyager";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
  };
}
