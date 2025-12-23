{ config, pkgs, lib, ... }:

{
  programs.waybar = {
    enable = lib.mkIf config.dotfiles.enableGui true;

    # Basic waybar configuration
    # Can be extended with declarative config or symlinked to existing
    systemd = {
      enable = true;
      target = "sway-session.target";
    };

    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 30;

        modules-left = [ "sway/workspaces" "sway/mode" ];
        modules-center = [ "sway/window" ];
        modules-right = [ "pulseaudio" "network" "cpu" "memory" "temperature" "battery" "clock" "tray" ];

        "sway/workspaces" = {
          disable-scroll = true;
          all-outputs = true;
        };

        "sway/mode" = {
          format = "<span style=\"italic\">{}</span>";
        };

        clock = {
          tooltip-format = "<big>{:%Y %B}</big>\\n<tt><small>{calendar}</small></tt>";
          format = "{:%Y-%m-%d %H:%M}";
        };

        cpu = {
          format = " {usage}%";
          tooltip = false;
        };

        memory = {
          format = " {}%";
        };

        temperature = {
          critical-threshold = 80;
          format = "{icon} {temperatureC}°C";
          format-icons = [ "" "" "" ];
        };

        battery = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = "{icon} {capacity}%";
          format-charging = " {capacity}%";
          format-plugged = " {capacity}%";
          format-alt = "{time} {icon}";
          format-icons = [ "" "" "" "" "" ];
        };

        network = {
          format-wifi = " {essid} ({signalStrength}%)";
          format-ethernet = " {ipaddr}/{cidr}";
          tooltip-format = " {ifname} via {gwaddr}";
          format-linked = " {ifname} (No IP)";
          format-disconnected = "⚠ Disconnected";
          format-alt = "{ifname}: {ipaddr}/{cidr}";
        };

        pulseaudio = {
          format = "{icon} {volume}%{format_source}";
          format-bluetooth = "{icon} {volume}%  {format_source}";
          format-bluetooth-muted = " {icon} {format_source}";
          format-muted = " {format_source}";
          format-source = " {volume}%";
          format-source-muted = "";
          format-icons = {
            headphone = "";
            hands-free = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = [ "" "" "" ];
          };
          on-click = "pavucontrol";
        };

        tray = {
          spacing = 10;
        };
      };
    };

    style = ''
      * {
        border: none;
        border-radius: 0;
        font-family: "JetBrainsMono Nerd Font", "Font Awesome 6 Free";
        font-size: 13px;
        min-height: 0;
      }

      window#waybar {
        background-color: rgba(43, 48, 59, 0.9);
        color: #ffffff;
        transition-property: background-color;
        transition-duration: .5s;
      }

      window#waybar.hidden {
        opacity: 0.2;
      }

      #workspaces button {
        padding: 0 5px;
        background-color: transparent;
        color: #ffffff;
        border-bottom: 3px solid transparent;
      }

      #workspaces button:hover {
        background: rgba(0, 0, 0, 0.2);
        box-shadow: inherit;
        border-bottom: 3px solid #ffffff;
      }

      #workspaces button.focused {
        background-color: #64727D;
        border-bottom: 3px solid #ffffff;
      }

      #workspaces button.urgent {
        background-color: #eb4d4b;
      }

      #mode {
        background-color: #64727D;
        border-bottom: 3px solid #ffffff;
      }

      #clock,
      #battery,
      #cpu,
      #memory,
      #temperature,
      #network,
      #pulseaudio,
      #tray,
      #mode,
      #idle_inhibitor {
        padding: 0 10px;
        margin: 0 4px;
        color: #ffffff;
      }

      #battery.charging {
        color: #26A65B;
      }

      #battery.warning:not(.charging) {
        color: #f39c12;
      }

      #battery.critical:not(.charging) {
        color: #f53c3c;
      }

      #temperature.critical {
        color: #eb4d4b;
      }
    '';
  };

  # Link to existing waybar config if it exists
  xdg.configFile."waybar" = lib.mkIf (config.dotfiles.enableGui && builtins.pathExists "${config.home.homeDirectory}/Dotfiles/.config/waybar") {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Dotfiles/.config/waybar";
    recursive = true;
  };
}
