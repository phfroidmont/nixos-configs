{
  config,
  options,
  lib,
  ...
}:

{
  options = {
    user = lib.my.mkOpt lib.types.attrs { };
  };

  config = {

    user = {
      name = "froidmpa";
      description = "The primary user account";
      extraGroups = [
        "wheel"
        "adbusers"
      ];
      isNormalUser = true;
    };

    users.users.${config.user.name} = lib.mkAliasDefinitions options.user;

    home-manager = {
      useUserPackages = true;

      users.${config.user.name} = {
        home = {
          enableNixpkgsReleaseCheck = true;
          inherit (config.system) stateVersion;
        };
      };
    };

  };
}
