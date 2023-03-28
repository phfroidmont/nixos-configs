{ config, options, lib, home-manager, ... }:

with lib;
with lib.my; {
  options = with types; { user = mkOpt attrs { }; };

  config = {

    user = {
      name = "froidmpa";
      description = "The primary user account";
      extraGroups = [ "wheel" "adbusers" ];
      isNormalUser = true;
    };

    users.users.${config.user.name} = mkAliasDefinitions options.user;

    home-manager = {
      useUserPackages = true;

      users.${config.user.name} = {
        home = {
          enableNixpkgsReleaseCheck = true;
          stateVersion = config.system.stateVersion;
        };
      };
    };

  };
}
