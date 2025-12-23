{ config, pkgs, lib, ... }:

{
  # Systemd user services
  systemd.user = {
    # Auto-update service (disabled by default in Home Manager context)
    # This would typically be a system-level service
    # Users can enable it manually if needed

    # Example user service for future use
    services = {
      # Add user-level services here as needed
    };

    timers = {
      # Add user-level timers here as needed
    };
  };

  # Link to existing systemd configurations
  # These are system-level services that need to be installed separately
  xdg.configFile."systemd/user" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Dotfiles/.config/systemd/user";
    recursive = true;
  };

  # Note: The auto-update service in .config/systemd/system/ is a system-level
  # service and should be managed by NixOS configuration or installed manually
  # It's not a user service and can't be managed by Home Manager
}
