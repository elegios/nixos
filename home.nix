{ config, lib, pkgs, fish-gi, miking-emacs, ... }@inputs:

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
    morgen
    firefox
    sway-switch-workspace
    sway-toggle-semi-fullscreen
    maestral-gui
    keepassxc
    signal-desktop
    qalculate-qt
    libqalculate
    (nerdfonts.override { fonts = ["UbuntuMono"]; })

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
    userName = "Viktor Palmkvist";
    userEmail = "vipa@kth.se";
    ignores = [ ".tup" "*~" ".direnv" ];
    aliases = {
      st = "status -s";
      co = "checkout";
      cob = "checkout -b";
      lsb = "branch -vv";
      ls = ''log --date=format:"%d/%m" --pretty=format:"%C(yellow)%h\\ %C(green)%ad%Cred%d\\ %Creset%s%Cblue\\ [%cn]" --decorate'';
    };
    extraConfig = {
      core.whitespace = "trailing-space,space-before-tab";
      interactive.singlekey = true;
      pull.ff = "only";
    };
    difftastic.enable = true;
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
      merge-tools.difftastic = {
        program = "${pkgs.difftastic}/bin/difft";
        diff-args = ["--color=always" "$left" "$right"];
      };
      ui.diff.tool = "difftastic";
      aliases = {
        ls = ["log" "--revisions" ''default() & and_parents((::@ ~ public())::)''];
        leaves = ["log" "--no-graph" "--revisions" ''leaves(all())''];
      };
      revsets.log = "default()";
      templates.log = "myOneline";
      git.fetch = "origin";
      git.push = "fork";
      ui.pager = "less -FRX";
      revset-aliases = {
        "public()" = "::origin_branches()";
        "and_parents(x)" = ''x | x-'';
        "leaves(x)" = ''heads(x)'';
        "default()" = ''and_parents(@ | (origin_branches()..)) | heads(origin_branches())'';
        "origin_branches()" = ''remote_branches(remote=exact:"origin")'';
      };
      template-aliases = {
        "format_short_id(id)" = ''id.shortest(4)'';
        "format_timestamp(timestamp)" = ''timestamp.ago()'';
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
              branches,
              tags,
              working_copies,
              format_timestamp(committer.timestamp()),
            )
            ++ "\n"
          )
        '';
      };
    };
  };

  stylix = {
    autoEnable = false;
    image = ./assets/wallpaper.png;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/solarized-dark.yaml";
    fonts.monospace = {
      package = pkgs.nerdfonts.override { fonts = ["UbuntuMono"]; };
      name = "Ubuntu Mono Nerd Font";
    };
    targets.kitty.enable = true;
    targets.gtk.enable = true;
    targets.fish.enable = true;
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

  # NOTE(vipa, 2023-07-22): First attempt at global theme switching, unfortunately causes infinite recursion
  # specialisation.dark.configuration = {
  #   wayland.windowManager.sway.config.keybindings."Mod4+v" = lib.mkForce "exec ${config.specPackages.light}/activate";
  # };
  # specialisation.light.configuration = {
  #   stylix.base16Scheme = lib.mkForce "${pkgs.base16-schemes}/share/themes/solarized-light.yaml";
  #   wayland.windowManager.sway.config.keybindings."Mod4+v" = lib.mkForce "exec ${config.home.activationPackage}/activate";
  # };

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
          # "${mod}+v" =
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
      #clock,#idle_inhibitor,#tray,#pulseaudio,#backlight,#network,#battery,#mode,#custom-idle {
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
    '';
    settings.mainBar = {
      position = "top";
      spacing = 4;
      modules-left = ["sway/workspaces" "sway/mode" "sway/scratchpad"];
      modules-center = ["clock" "idle_inhibitor" "custom/idle"];
      modules-right = ["tray" "pulseaudio" "backlight" "network" "battery"];
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

  home.shellAliases.jless = "jless --clipboard-cmd wl-copy";
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      bind \b 'backward-kill-word'
      set fish_greeting
      set -gx EDITOR emacs
      set -gx PAGER "less -R"

      # Expand ... to ../.., .... to ../../.., etc.
      function multicd
        echo cd (string repeat -n (math (string length -- $argv[1]) - 1) ../)
      end
      abbr --add dotdot --regex '^\.\.+$' --function multicd

      # Auto-complete revisions and branches for `jj` commands
      function __changes
        jj log -r :: --no-graph -T 'change_id.shortest() ++ "\t" ++  description.first_line() ++ "\n"'
      end
      function __branches
        jj log -r 'branches()' --no-graph -T 'branches.map(|b| b.name() ++ "\t" ++ description.first_line() ++ "\n")'
      end
      complete -f -c jj -s r -l revision -r -d 'Revision' -ka '( __changes )'
      complete -f -c jj -n '__fish_seen_subcommand_from show' -ka '(__changes)'
      complete -f -c jj -n '__fish_seen_subcommand_from branch set' -ka '(__branches)'
      complete -f -c jj -n '__fish_seen_subcommand_from branch track' -ka '(__branches)'
      complete -f -c jj -n '__fish_seen_subcommand_from new' -ka '(__branches; __changes)'
      complete -f -c jj -n '__fish_seen_subcommand_from new' -s b -ka '(__branches)'
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
    package = (pkgs.emacsPackagesFor pkgs.emacs29-pgtk).emacsWithPackages
      (epkgs: builtins.attrValues {
        inherit (epkgs.treesit-grammars) with-all-grammars;
      } ++
      [ (epkgs.trivialBuild rec {
          pname = "miking-emacs";
          version = "1";
          src = miking-emacs;
        })
      ]);
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
      # Remove the titlebar, since I use sidebery instead
      userChrome = ''
      #titlebar {
        visibility: collapse !important;
      }
      '';
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
