{ config, pkgs, lib, ... }:

{
  programs.btop = {
    enable = true;

    settings = {
      color_theme = "Default";
      theme_background = false;
      truecolor = true;
      force_tty = false;
      vim_keys = true;
      rounded_corners = true;
      graph_symbol = "braille";
      graph_symbol_cpu = "default";
      graph_symbol_mem = "default";
      graph_symbol_net = "default";
      graph_symbol_proc = "default";
      shown_boxes = "cpu mem net proc";
      update_ms = 1000;
      proc_sorting = "cpu lazy";
      proc_reversed = false;
      proc_tree = false;
      proc_colors = true;
      proc_gradient = true;
      proc_per_core = false;
      proc_mem_bytes = true;
      cpu_graph_upper = "total";
      cpu_graph_lower = "total";
      cpu_invert_lower = true;
      cpu_single_graph = false;
      show_uptime = true;
      check_temp = true;
      show_coretemp = true;
      temp_scale = "celsius";
      show_cpu_freq = true;
      clock_format = "%X";
      background_update = true;
      custom_cpu_name = "";
      disks_filter = "";
      mem_graphs = true;
      show_swap = true;
      swap_disk = true;
      show_disks = true;
      only_physical = true;
      use_fstab = false;
      net_download = 100;
      net_upload = 100;
      net_auto = true;
      net_sync = false;
      net_color_fixed = false;
      net_iface = "";
      show_battery = true;
      show_init = false;
      log_level = "WARNING";
    };
  };
}
