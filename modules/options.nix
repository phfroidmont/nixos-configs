{
  config,
  lib,
  ...
}:

{
  options = {
    user.name = lib.mkOption {
      type = lib.types.str;
      description = "Name of the primary user account.";
    };
  };

  config = {

    users.users.${config.user.name} = {
      description = lib.mkDefault "The primary user account";
      extraGroups = [ "wheel" ];
      isNormalUser = true;
    };

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
