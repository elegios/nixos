{ config, lib, pkgs, fish-gi, miking-emacs, typst-ts-mode, ... }@inputs:

let
  sway-switch-workspace = pkgs.writeTextFile {
    name = "sway-switch-workspace";
    destination = "/bin/sway-switch-workspace";
    executable = true;

    text = ''
      #!/usr/bin/env bash

      if [ $# -lt 1 ]; then
        echo Usage: $0 WORKSPACE
        exit 1
      fi

      WORKSPACE=$1

      FOCUSED_OUTPUT=$(swaymsg -t get_outputs --raw | jq '. | map(select(.focused == true)) | .[0].name' -r)
      swaymsg "[workspace=^''${WORKSPACE}$]" move workspace to output "''${FOCUSED_OUTPUT}"
      swaymsg workspace $WORKSPACE
    '';
  };
  sway-toggle-semi-fullscreen = pkgs.writeTextFile {
    name = "sway-toggle-semi-fullscreen";
    destination = "/bin/sway-toggle-semi-fullscreen";
    executable = true;

    text = ''
      #!/usr/bin/env bash

      LAYOUT=$(swaymsg -t get_tree --raw | jq --raw-output 'recurse(.nodes[]) | select(.nodes[].focused) | .layout')

      case $LAYOUT in
        splitv | stacked | stacking)
          swaymsg layout toggle splitv stacking
          ;;
        splith | tabbed)
          swaymsg layout toggle splith tabbed
          ;;
        *)
          swaynag -t warning -m "Container had a weird layout: $LAYOUT"
          ;;
      esac
    '';
  };
  set-idle = pkgs.writeShellScript "set-idle" ''
    ${pkgs.coreutils}/bin/rm -f ~/.idle-end-time
  '';
  unset-idle = pkgs.writeShellScript "unset-idle" ''
    ${pkgs.coreutils}/bin/date +%s > ~/.idle-end-time
  '';
  format-idle = pkgs.writeShellScript "format-idle" ''
    if [ -e ~/.idle-end-time ]; then
      SECS=$(($(${pkgs.coreutils}/bin/date +%s) - $(cat ~/.idle-end-time)))
      D=$((SECS/60/60/24))
      H=$((SECS/60/60%24))
      M=$((SECS/60%60))
      (( $D > 0 )) && printf '%dd ' $D
      (( $H > 0 )) && printf '%dh ' $H
      printf '%dm\n' $M
    else
      echo IDLE
    fi
  '';
  custom-jless = pkgs.jless.overrideAttrs (old: {
    cargoBuildNoDefaultFeatures = true;
    cargoCheckNoDefaultFeatures = true;
    patches = old.patches ++ [(pkgs.fetchpatch {
      url = "https://github.com/PaulJuliusMartinez/jless/pull/121.patch";
      hash = "sha256-YlojwH2ITbq2l/7bOSF6qsMhkgqe6Xm7p3P/ZgiLSCU=";
    })];
  });
  toggle-theme = pkgs.writeShellScript "toggle-theme" ''
    if [ -d "$(${pkgs.home-manager}/bin/home-manager generations | head -1 | rg -o '/[^ ]*')"/specialisation ]; then
      "$(${pkgs.home-manager}/bin/home-manager generations | head -1 | rg -o '/[^ ]*')"/specialisation/light/activate
    else
      "$(${pkgs.home-manager}/bin/home-manager generations | head -2 | tail -1 | rg -o '/[^ ]*')"/activate
    fi
  '';
in

rec {
  # NOTE(vipa, 2023-07-22): First attempt at global theme switching, unfortunately causes infinite recursion
  # imports = [ ./modules/ele-spec.nix ];

  home.username = "vipa";
  home.homeDirectory = "/home/vipa";

  # Packages that should be installed to the user profile.

  home.packages = with pkgs; [
    # apps
    obsidian
    zoom-us
    spotify
    zotero
    # TODO(vipa, 2023-07-29): Setting up thunderbird currently
    # requires editing ~/.thunderbird/profiles.ini to point to the
    # profile directory inside Dropbox. Ideally this would be set-up
    # automatically
    thunderbird
    # morgen
    sway-switch-workspace
    sway-toggle-semi-fullscreen
    maestral-gui
    keepassxc
    signal-desktop
    qalculate-qt
    libqalculate
    nerd-fonts.ubuntu-mono
    anki

    # archives
    zip
    xz
    unzip
    p7zip
    dtrx

    # utils
    fd
    pavucontrol
    ripgrep # recursively searches directories for a regex pattern
    jq # A lightweight and flexible command-line JSON processor
    gron
    custom-jless
    meld
    visidata
    entr
    libnotify
    nodejs_20
    (callPackage ./pkgs/edir {})
    tesseract
    wl-mirror

    # networking tools
    dnsutils  # `dig` + `nslookup`
    ldns # replacement of `dig`, it provide the command `drill`
    ipcalc  # it is a calculator for the IPv4/v6 addresses

    # misc
    cloc
    file
    which
    tree
    gnused
    gnutar
    gawk
    zstd
    gnupg

    # nix related
    #
    # it provides the command `nom` works just like `nix`
    # with more details log output
    nix-output-monitor
    nvd

    btop  # replacement of htop/nmon
    iotop # io monitoring
    iftop # network monitoring

    # system call monitoring
    strace # system call monitoring
    ltrace # library call monitoring
    lsof # list open files

    # system tools
    sysstat
    lm_sensors # for `sensors` command
    ethtool
    pciutils # lspci
    usbutils # lsusb
  ];

  systemd.user.timers.clear-downloads = {
    Unit = { Description = "Periodically clear the downloads folder"; };
    Timer = {
      OnCalendar = "daily";
      RandomizedDelaySec = 600;
      Persistent = true;
      Unit = "clear-downloads.service";
    };
    Install = { WantedBy = [ "sway-session.target" ]; };
  };
  systemd.user.services.clear-downloads = {
    Unit = { Description = "Periodically clear the downloads folder"; };
    Service =
      let
        script = pkgs.writeShellScript "clear-downloads" ''
          ${pkgs.findutils}/bin/find ~/Downloads/ -mindepth 1 -maxdepth 1 -ctime +3 -exec rm -r "{}" \;
        '';
      in {
        Type = "oneshot";
        ExecStart = "${script}";
      };
  };

  systemd.user.services.maestral = {
    Unit.Description = "Maestral daemon";
    Install.WantedBy = [ "default.target" ];
    Service = {
      ExecStart = "${pkgs.maestral-gui}/bin/maestral start -f";
      ExecStop = "${pkgs.maestral-gui}/bin/maestral stop";
      Restart = "on-failure";
      Nice = 10;
    };
  };
  systemd.user.services.maestral_qt = {
    Unit.Description = "Maestral daemon";
    Install.WantedBy = [ "sway-session.target" ];
    Service = {
      ExecStart = "${pkgs.maestral-gui}/bin/maestral_qt";
      Restart = "on-failure";
    };
  };

  # TODO(vipa, 2023-07-29): This seems broken atm: https://github.com/nix-community/home-manager/issues/4226
  # services.dropbox = {
  #   enable = true;
  #   path = home.homeDirectory + "/Dropbox";
  # };

  programs.gh.enable = true;
  programs.gh.settings = {
    # Workaround for https://github.com/nix-community/home-manager/issues/4744
    version = 1;
  };
  programs.git = {
    enable = true;
    settings = {
      core.whitespace = "trailing-space,space-before-tab";
      interactive.singlekey = true;
      pull.ff = "only";
      alias = {
        st = "status -s";
        co = "checkout";
        cob = "checkout -b";
        lsb = "branch -vv";
        ls = ''log --date=format:"%d/%m" --pretty=format:"%C(yellow)%h\\ %C(green)%ad%Cred%d\\ %Creset%s%Cblue\\ [%cn]" --decorate'';
      };
      user.name = "Viktor Palmkvist";
      user.email = "vipa@kth.se";
    };
    ignores = [ ".tup" "*~" ".direnv" ];
  };

  programs.difftastic = {
    enable = true;
    git.enable = true;
  };

  programs.jujutsu = {
    enable = true;
    # NOTE(vipa, 2024-05-13): The way the `ediff` option is
    # implemented overwrites any `merge-tools` in `settings` it seems
    # like, so I turn it off for now. Relevant PR:
    # https://github.com/nix-community/home-manager/pull/5371
    ediff = false;
    settings = {
      user.name = "Viktor Palmkvist";
      user.email = "vipa@kth.se";
      ui = {
        diff-formatter = "difftastic";
        pager = "less -FRX";
        default-command = "log-stack";
      };
      merge-tools.difftastic = {
        program = "${pkgs.difftastic}/bin/difft";
        diff-args = ["--color=always" "$left" "$right"];
        diff-invocation-mode = "file-by-file";
      };
      git = {
        fetch = "origin";
        push = "fork";
        private-commits = "private()";
      };
      aliases = {
        # Log only the current stack
        log-stack = ["log" "--revisions" "stack()" "--template" "myOneline ++ diffStatIfCurrent"];
        # Show all leaves in the repository, without a graph
        leaves = ["log" "--no-graph" "--revisions" ''leaves(all())''];
        # Move closest bookmark(s) to the most recent non-private revision
        tug = ["bookmark" "move" "--from" "leaves(::@- & bookmarks())" "--to" "leaves(::@- ~ private():: ~ empty())"];
        # Move something on top of trunk
        retrunk = ["rebase" "-d" "trunk()"];
        # Move the current stack to trunk
        reheat = ["rebase" "-d" "trunk()" "-s" "roots(trunk()..stack(@))"];
      };
      revsets = {
        log = "stack(mine() | @) | trunk() | @";
        log-graph-prioritize = "coalesce(megamerge(), trunk())";
      };
      revset-aliases = {
        "user(x)" = "author(x) | committer(x)";

        "stack()" = "stack(@)";
        "stack(x)" = "stack(x, 2)";
        "stack(x, n)" = "ancestors(reachable(x, mutable()), n)";

        "mine()" = "user('vipa@kth.se')";

        "private()" = "description('#no-push')";

        "megamerge()" = "coalesce(present(megamerge), stack() & merges())";

        # leaves is a more natural name for me
        "leaves(x)" = "heads(x)";
      };
      templates.log = "myOneline";
      template-aliases = {
        "format_short_id(id)" = ''id.shortest(4)'';

        "format_timestamp(timestamp)" = ''
          timestamp.ago().remove_suffix(" ago").remove_suffix("s").remove_suffix(" second").remove_suffix(" minute").remove_suffix(" hour").remove_suffix(" day").remove_suffix(" week").remove_suffix(" month").remove_suffix(" year")
          ++ label("timestamp",
            if(timestamp.ago().ends_with(" seconds ago") || timestamp.ago().ends_with(" second ago"), "s") ++
            if(timestamp.ago().ends_with(" minutes ago") || timestamp.ago().ends_with(" minute ago"), "m") ++
            if(timestamp.ago().ends_with(" hours ago") || timestamp.ago().ends_with(" hour ago"), "h") ++
            if(timestamp.ago().ends_with(" days ago") || timestamp.ago().ends_with(" day ago"), "d") ++
            if(timestamp.ago().ends_with(" weeks ago") || timestamp.ago().ends_with(" week ago"), "w") ++
            if(timestamp.ago().ends_with(" months ago") || timestamp.ago().ends_with(" month ago"), "mo") ++
            if(timestamp.ago().ends_with(" years ago") || timestamp.ago().ends_with(" year ago"), "y"))
        '';
        myOneline = ''
          label(if(current_working_copy, "working_copy"),
            separate(" ",
              if(divergent,
                label("divergent", format_short_id(change_id)),
                format_short_id(change_id)),
              format_short_id(commit_id),
              if(description, description.first_line(), description_placeholder),
              if(empty, label("empty", "(empty)")),
              if(conflict, label("conflict", "conflict")),
              bookmarks,
              tags,
              working_copies,
              format_timestamp(committer.timestamp()),
            )
            ++ "\n"
          )
        '';
        diffStatIfCurrent = ''
          if(current_working_copy,diff.stat() ++ "\n")
        '';
      };
    };
  };

  stylix = {
    enable = true;
    polarity = "dark";
    autoEnable = false;
    image = ./assets/wallpaper.png;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/solarized-dark.yaml";
    fonts.monospace = {
      package = pkgs.nerd-fonts.ubuntu-mono;
      name = "Ubuntu Mono Nerd Font";
    };
    targets.kitty.enable = true;
    targets.kitty.variant256Colors = true;
    targets.gtk.enable = true;
    targets.swaylock.enable = true;
    targets.zathura.enable = true;
  };

  programs.zathura.enable = true;
  # TODO(vipa, 2023-10-24): This seems like it might be nicer for paper reading, but it renders poorly, maybe look into later
  programs.sioyek = {
    enable = true;
    config = {
      vertical_move_amount = "3";
    };
  };

  specialisation.light.configuration = {
    stylix.base16Scheme = lib.mkForce "${pkgs.base16-schemes}/share/themes/solarized-light.yaml";
    stylix.fonts.sizes.terminal = 20;
  };

  programs.swaylock.enable = true;
  services.swayidle = {
    enable = true;
    events = [
      { event = "before-sleep"; command = "${set-idle}; ${pkgs.swaylock}/bin/swaylock -f"; }
      { event = "after-resume"; command = "${unset-idle}"; }
      { event = "lock"; command = "${pkgs.swaylock}/bin/swaylock -f"; }
    ];
    timeouts = [
      { timeout = 60 * 5; command = "${set-idle}"; resumeCommand = "${unset-idle}"; }
      { timeout = 60 * 15; command = "${pkgs.swaylock}/bin/swaylock -f"; }
    ];
  };

  wayland.windowManager.sway = {
    enable = true;
    config =
      let
        mod = "Mod4";
        up = "c";
        right = "n";
        down = "t";
        left = "h";
      in {
        bars = [];
        terminal = "kitty";
        startup = [
          { command = "waybar"; }
          { command = "ulauncher --hide-window > ~/logs/ulauncher.log 2>&1"; }
          { command = "${unset-idle}"; }
        ];
        input."type:keyboard" = {
          xkb_layout = "se";
          xkb_variant = "svdvorak";
          xkb_options = "caps:backspace";
        };
        input."type:touchpad".natural_scroll = "enabled";
        input."type:pointer".pointer_accel = "-0.7";
        input."type:tablet_tool".map_to_output = "DP-1";
        input."1386:209:Wacom_Bamboo_2FG_4x5_Finger".events = "disabled";
        floating.modifier = mod;
        keybindings = {
          # External programs
          "${mod}+Shift+Return" = "exec kitty";
          "${mod}+space" = "exec ulauncher-toggle";
          # Sway and session things
          "${mod}+Shift+r" = "reload";
          "${mod}+q" = ''exec swaynag -t warning -m "You pressed the exit shortcut. Do you really want to exit sway? This will end your Wayland session." -B "Yes, exit sway" "swaymsg exit"'';
          "${mod}+l" = ''exec loginctl lock-session'';
          # Special keys
          "--locked XF86AudioLowerVolume" = ''exec pactl set-sink-volume @DEFAULT_SINK@ -5%'';
          "--locked XF86AudioRaiseVolume" = ''exec pactl set-sink-volume @DEFAULT_SINK@ +5%'';
          "--locked XF86AudioMute" = ''exec pactl set-sink-mute @DEFAULT_SINK@ toggle'';
          "--locked XF86MonBrightnessDown" = ''exec brightnessctl set 5%-'';
          "--locked XF86MonBrightnessUp" = ''exec brightnessctl set +5%'';

          # NOTE(vipa, 2023-07-22): First attempt at global theme switching, this might be fine, or more likely causes infinite recursion
          "${mod}+v" = "exec ${toggle-theme}";
          #   if config.specPackages ? light
          #   then "exec ${config.specPackages.light}/activate"
          #   else ''swaynag -t warning -m "Couldn't find the spec for light mode, not switching."'';

          # Simple (non-movement) window manipulation
          "${mod}+w" = "kill";
          "${mod}+Shift+f" = "fullscreen";
          "${mod}+Minus" = "focus mode_toggle";
          "${mod}+Shift+Minus" = "floating toggle";
          # Container related manipulation
          "${mod}+Up" = "focus parent";
          "${mod}+Down" = "focus child";
          "${mod}+s" = "split toggle";
          "${mod}+Shift+s" = "split none";
          "${mod}+f" = "exec sway-toggle-semi-fullscreen";
          # Basic window movement
          "${mod}+${left}" = "focus left";
          "${mod}+${down}" = "focus down";
          "${mod}+${up}" = "focus up";
          "${mod}+${right}" = "focus right";
          "${mod}+Shift+${left}" = "move left";
          "${mod}+Shift+${down}" = "move down";
          "${mod}+Shift+${up}" = "move up";
          "${mod}+Shift+${right}" = "move right";
          "${mod}+o" = "focus output right";
          "${mod}+Shift+o" = "move output right";
          # Workspace commands
          "${mod}+1" = "exec sway-switch-workspace 1";
          "${mod}+2" = "exec sway-switch-workspace 2";
          "${mod}+3" = "exec sway-switch-workspace 3";
          "${mod}+4" = "exec sway-switch-workspace 4";
          "${mod}+5" = "exec sway-switch-workspace 5";
          "${mod}+6" = "exec sway-switch-workspace 6";
          "${mod}+7" = "exec sway-switch-workspace 7";
          "${mod}+8" = "exec sway-switch-workspace 8";
          "${mod}+9" = "exec sway-switch-workspace 9";
          "${mod}+0" = "exec sway-switch-workspace 10";
          "${mod}+Shift+1" = "move container to workspace number 1";
          "${mod}+Shift+2" = "move container to workspace number 2";
          "${mod}+Shift+3" = "move container to workspace number 3";
          "${mod}+Shift+4" = "move container to workspace number 4";
          "${mod}+Shift+5" = "move container to workspace number 5";
          "${mod}+Shift+6" = "move container to workspace number 6";
          "${mod}+Shift+7" = "move container to workspace number 7";
          "${mod}+Shift+8" = "move container to workspace number 8";
          "${mod}+Shift+9" = "move container to workspace number 9";
          "${mod}+Shift+0" = "move container to workspace number 10";
          # Modes
          "${mod}+r" = ''mode "resize"'';
        };
        modes.resize = {
          "${left}" = "resize shrink width 10px";
          "${right}" = "resize grow width 10px";
          "${up}" = "resize shrink height 10px";
          "${down}" = "resize grow height 10px";
          "${mod}+${left}" = "resize shrink width 10px";
          "${mod}+${right}" = "resize grow width 10px";
          "${mod}+${up}" = "resize shrink height 10px";
          "${mod}+${down}" = "resize grow height 10px";
          "Return" = ''mode "default"'';
          "Escape" = ''mode "default"'';
          "Space" = ''mode "default"'';
          "Shift+Return" = ''mode "default"'';
          "Shift+Escape" = ''mode "default"'';
          "Shift+Space" = ''mode "default"'';
        };
        window.commands = [
          { command = "floating enable, border none"; criteria = { app_id = "^ulauncher$"; }; }
          { command = "floating enable, sticky enable"; criteria = { title = "^Firefox — Sharing Indicator$"; app_id = "firefox"; }; }
          { command = "floating enable, border none, sticky enable"; criteria = { title = "^as_toolbar$"; app_id = ""; }; }
          { command = "floating enable, border none"; criteria = { title = "^zoom$"; app_id = ""; }; }
          { command = ''title_format "%title :: %shell"''; criteria = { shell = "^xwayland$"; }; }
        ];
        output."*".bg = "${config.stylix.image} fill";
        gaps.smartBorders = "on";
        colors = with config.lib.stylix.colors.withHashtag; {
          focused = {
            background = base02;
            border = base03;
            text = base07;
            indicator = base0E;
            childBorder = base03;
          };
          focusedInactive = {
            background = base02;
            border = base01;
            text = base07;
            indicator = base0E;
            childBorder = base01;
          };
          unfocused = {
            background = base01;
            border = base01;
            text = base07;
            indicator = base0E;
            childBorder = base01;
          };
          urgent = {
            background = base08;
            border = base01;
            text = base00;
            indicator = base0E;
            childBorder = base01;
          };
        };
      };
  };

  programs.waybar = {
    enable = true;
    style = with config.lib.stylix.colors.withHashtag; ''
      @define-color base00 ${base00}; @define-color base01 ${base01}; @define-color base02 ${base02}; @define-color base03 ${base03};
      @define-color base04 ${base04}; @define-color base05 ${base05}; @define-color base06 ${base06}; @define-color base07 ${base07};

      @define-color base08 ${base08}; @define-color base09 ${base09}; @define-color base0A ${base0A}; @define-color base0B ${base0B};
      @define-color base0C ${base0C}; @define-color base0D ${base0D}; @define-color base0E ${base0E}; @define-color base0F ${base0F};
      * {
        border: none;
        border-radius: 20px;
        font-family: Font Awesome, Roboto, Arial, sans-serif;
        font-size: 13px;
        color: @base05;
      }
      window#waybar {
        background: @base00;
        border-radius: 0px;
      }
      window#waybar > box {
        padding: 5px 5px;
      }
      .modules-right, .modules-center, .modules-left {
        background-color: @base01;
      }
      #clock,#idle_inhibitor,#tray,#pulseaudio,#backlight,#network,#battery,#mode,#custom-idle,#memory {
        padding: 0 10px;
      }
      #workspaces button:first-child {
        padding: 1px 1px 1px 5px;
        border-radius: 20px 0px 0px 20px;
      }
      #workspaces button {
        padding: 1px;
        border-radius: 0px;
      }
      #workspaces button:last-child {
        padding: 1px 5px 1px 1px;
        border-radius: 0px 20px 20px 0px;
      }
      #workspaces button {
        background-color: transparent;
      }
      #workspaces button:hover {
        background-color: @base04;
      }
      #workspaces button.focused {
        background-color: @base03;
      }
      #workspaces button.urgent {
        background-color: @base09;
      }
      #mode {
        color: @base0C;
        font-weight: bold;
      }
      #idle_inhibitor.activated {
        color: @base0C;
      }
      #battery.charging {
        color: @base0C;
      }
      #battery.warning:not(.charging) {
        color: @base0A;
      }
      #battery.critical:not(.charging) {
        color: @base09;
      }
      #memory.warning {
        color: @base0A;
      }
      #memory.critical {
        color: @base09;
      }
    '';
    settings.mainBar = {
      position = "top";
      spacing = 4;
      modules-left = ["sway/workspaces" "sway/mode" "sway/scratchpad"];
      modules-center = ["clock" "idle_inhibitor" "custom/idle"];
      modules-right = ["tray" "pulseaudio" "backlight" "network" "memory" "battery"];
      "sway/workspaces".disable-scroll = true;
      "sway/mode".format = ''<span style="italic">{}</span>'';
      "sway/scratchpad" = {
        format = "{icon} {count}";
        show-empty = false;
        format-icons = ["" ""];
        tooltip = true;
        tooltip-format = "{app}: {title}";
      };
      clock = {
        tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        format = "{:%Y-%m-%d %H:%M}";
      };
      idle_inhibitor = {
        format = "{icon}";
        format-icons = {
          activated = "";
          deactivated = "";
        };
      };
      "custom/idle" = {
        exec = "${format-idle}";
        format = "{}";
        interval = 1;
      };
      tray.spacing = 10;
      pulseaudio = {
        format = "{volume}% {icon}";
        format-bluetooth = "{volume}% {icon}";
        format-bluetooth-muted = " {icon}";
        format-muted = "";
        format-source = "{volume}% ";
        format-source-muted = "";
        tooltip-format = "{volume}% {icon} {format_source}";
        tooltip-format-bluetooth = "{volume}% {icon} {format_source}";
        tooltip-format-bluetooth-muted = " {icon} {format_source}";
        tooltip-format-muted = " {format_source}";
        format-icons = {
          headphone = "";
          hands-free = "";
          headset = "";
          phone = "";
          portable = "";
          car = "";
          default = ["" "" ""];
        };
        on-click = "pavucontrol";
      };
      backlight.format = "{percent}% ";
      network = {
        format-wifi = "{essid} ";
        format-ethernet = "";
        tooltip-format-ethernet = "{ipaddr}/{cidr}";
        tooltip-format-wifi = "{essid} ({signalStrength}%)";
        format-linked = "{ifname} (No IP) ";
        format-disconnected = "Disconnected ⚠";
        on-click = "kitty nmtui";
      };
      memory = {
        interval = 1;
        format = "{avail:0.1f}G ";
        states = {
          warning = 70;
          critical = 85;
        };
      };
      battery = {
        states = {
          warning = 30;
          critical = 15;
        };
        format = "{capacity}% {icon}";
        format-charging = "{capacity}% ";
        format-plugged = "{capacity}% ";
        format-alt = "{time} {icon}";
        format-icons = ["" "" "" "" ""];
      };
    };
  };

  programs.kitty = {
    enable = true;
    settings = {
      shell = "fish";
      scrollback_page_history_size = 2;
    };
    keybindings = {
      "ctrl+shift+g" = "show_last_non_empty_command_output";
      "ctrl+shift+up" = "scroll_to_prompt -1";
      "ctrl+shift+down" = "scroll_to_prompt 1";
      "ctrl+o" = "kitten hints --type path";
    };
    extraConfig = ''
      mouse_map right doublepress ungrabbed mouse_select_command_output
    '';
  };

  programs.bash = {
    enable = true;
    enableCompletion = true;
  };

  home.activation.configure-tide = lib.hm.dag.entryAfter ["writeBoundary"] ''
    ${pkgs.fish}/bin/fish -c "tide configure --auto --style=Lean --prompt_colors='True color' --show_time='24-hour format' --lean_prompt_height='Two lines' --prompt_connection=Disconnected --prompt_spacing=Sparse --icons='Few icons' --transient=No"
    ${pkgs.fish}/bin/fish -c "set -U tide_left_prompt_items pwd jj newline character"
    ${pkgs.fish}/bin/fish -c "set -U tide_right_prompt_items status cmd_duration context jobs node python rustc java php ruby go kubectl toolbox terraform aws nix_shell crystal time"
    ${pkgs.fish}/bin/fish -c "set -U tide_jj_truncation_length 40"
    ${pkgs.fish}/bin/fish -c "set -U tide_jj_icon"
    ${pkgs.fish}/bin/fish -c "set -U tide_jj_color_conflict \$tide_git_color_conflicted"
    ${pkgs.fish}/bin/fish -c "set -U tide_jj_color_description normal"
    ${pkgs.fish}/bin/fish -c "set -U tide_jj_color_branch \$tide_git_color_branch"
    ${pkgs.fish}/bin/fish -c "set -U tide_jj_color_content \$tide_git_color_staged"
  '';
  programs.fish = {
    enable = true;
    functions.jless = ''
      if contains -- --help $argv
          command jless $argv
          return
      end
      if isatty
          echo "This jless alias requires input to be given over stdin"
          return 1
      end
      jq -R '. as $line | try fromjson catch ("-> " + $line)' | command jless --clipboard-cmd wl-copy $argv
    '';
    interactiveShellInit = ''
      bind \b 'backward-kill-word'
      set fish_greeting
      set -gx EDITOR emacs
      set -gx PAGER less -R

      # Expand ... to ../.., .... to ../../.., etc.
      function multicd
        echo cd (string repeat -n (math (string length -- $argv[1]) - 1) ../)
      end
      abbr --add dotdot --regex '^\.\.+$' --function multicd

      function last_history_item
          echo $history[1]
      end
      abbr -a !! --position anywhere --function last_history_item
    '';
    plugins = with pkgs.fishPlugins; [
      { name = "tide"; src = tide.src; }
      { name = "done"; src = done.src; }
      { name = "gi"; src = fish-gi; }
      { name = "tide_jj_item"; src = (callPackage ./pkgs/tide_jj_item {}).src; }
      { name = "sd_fish_completion"; src = (callPackage ./pkgs/sd_fish_completion {}).src; }
    ];
  };

  programs.emacs = {
    enable = true;
    package = (pkgs.emacsPackagesFor pkgs.emacs-pgtk).emacsWithPackages
      (epkgs: builtins.attrValues {
        inherit (epkgs.treesit-grammars) with-all-grammars;
      } ++
      [ (epkgs.trivialBuild rec {
          pname = "miking-emacs";
          version = "1";
          src = miking-emacs;
        })
        (epkgs.trivialBuild rec {
          pname = "typst-ts-mode";
          version = "1";
          src = typst-ts-mode;
        })
      ]);
    extraConfig = ''
      (setq languagetool-java-arguments '("-Dfile.encoding=UTF-8" "-cp" "${pkgs.languagetool}/share/"))
      (setq languagetool-java-bin "${pkgs.jre}/bin/java")
      (setq languagetool-console-command "${pkgs.languagetool}/share/languagetool-commandline.jar")
      (setq languagetool-server-command "${pkgs.languagetool}/share/languagetool-server.jar")
    '';
  };
  xdg.configFile."emacs/init.el".source = ./dotfiles/emacs/init.el;
  xdg.configFile."emacs/early-init.el".source = ./dotfiles/emacs/early-init.el;
  xdg.configFile."emacs/lisp".source = ./dotfiles/emacs/lisp;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  fonts.fontconfig.enable = true;

  programs.firefox = {
    enable = true;
    profiles.vipa = {
      id = 0;
      isDefault = true;
      name = "vipa";
    };
  };

  programs.script-directory = {
    enable = true;
    settings.SD_ROOT = "${config.xdg.configHome}/nixos/dotfiles/sd-root";
  };

  xdg.configFile."fd/ignore".text = ".jj/";

  # This value determines the home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update home Manager without changing this value. See
  # the home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "23.05";

  # Let home Manager install and manage itself.
  programs.home-manager.enable = true;
}
