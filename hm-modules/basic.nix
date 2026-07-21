{ config, lib, pkgs, fish-gi, miking-emacs, typst-ts-mode, ... }@inputs:

let
  custom-jless = pkgs.jless.overrideAttrs (old: {
    cargoBuildNoDefaultFeatures = true;
    cargoCheckNoDefaultFeatures = true;
    patches = old.patches ++ [(pkgs.fetchpatch {
      url = "https://github.com/PaulJuliusMartinez/jless/pull/121.patch";
      hash = "sha256-YlojwH2ITbq2l/7bOSF6qsMhkgqe6Xm7p3P/ZgiLSCU=";
    })];
  });
  # NOTE(vipa, 2026-04-20): This was broken by a change to
  # home-manager (it was using experimental features, so that's fair I
  # guess)
  # toggle-theme = pkgs.writeShellScript "toggle-theme" ''
  #   if [ -d "$(${pkgs.home-manager}/bin/home-manager generations | head -1 | rg -o '/[^ ]*')"/specialisation ]; then
  #     "$(${pkgs.home-manager}/bin/home-manager generations | head -1 | rg -o '/[^ ]*')"/specialisation/light/activate
  #   else
  #     "$(${pkgs.home-manager}/bin/home-manager generations | head -2 | tail -1 | rg -o '/[^ ]*')"/activate
  #   fi
  # '';
in

{
  home.username = "vipa";
  home.homeDirectory = "/home/vipa";

  xdg.enable = true;
  xdg.mime.enable = true;
  xdg.mimeApps.enable = true;
  xdg.mimeApps.defaultApplicationPackages = [pkgs.emacs];
  xdg.mimeApps.defaultApplications."text/markdown" = "emacs.desktop";

  home.packages = with pkgs; [
    # archives
    zip
    xz
    unzip
    p7zip
    dtrx

    # utils
    moreutils
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
    nodejs
    (callPackage ../pkgs/edir {})

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
          ${pkgs.findutils}/bin/find ~/Downloads/ -mindepth 1 -maxdepth 1 -ctime +3 -exec ${pkgs.coreutils}/bin/rm -r "{}" \;
        '';
      in {
        Type = "oneshot";
        ExecStart = "${script}";
      };
  };

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
      remotes.fork.auto-track-bookmarks = "glob:*";
      remotes.origin.auto-track-bookmarks = "regex:main|master|trunk";
      aliases = {
        # Log only the current stack
        log-stack = ["log" "--revisions" "stack()" "--template" "myOneline ++ diffStatIfCurrent"];
        # Show all leaves in the repository, without a graph
        leaves = ["log" "--no-graph" "--revisions" ''leaves(all())''];
        # Move closest bookmark(s) to the most recent non-private revision
        tug = ["bookmark" "move" "--from" "leaves(::@- & bookmarks())" "--to" "leaves(::@- ~ private():: ~ empty())"];
        # Move something on top of trunk
        retrunk = ["rebase" "--onto" "trunk()"];
        # Move the current stack to trunk
        reheat = ["rebase" "--onto" "trunk()" "-s" "roots(trunk()..stack(@))"];
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

        "mine()" = "user(exact:'vipa@kth.se')";

        "private()" = "description(substring:'#no-push')";

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
      "ctrl+plus" = "change_font_size current +2.0";
      "ctrl+minus" = "change_font_size current -2.0";
      "ctrl+0" = "change_font_size current 0.0";
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
    ${pkgs.fish}/bin/fish -c "set -lpx fish_function_path ${pkgs.fishPlugins.tide.src}/functions; tide configure --auto --style=Lean --prompt_colors='True color' --show_time='24-hour format' --lean_prompt_height='Two lines' --prompt_connection=Disconnected --prompt_spacing=Sparse --icons='Few icons' --transient=No"
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
      { name = "tide_jj_item"; src = (callPackage ../pkgs/tide_jj_item {}).src; }
      { name = "sd_fish_completion"; src = (callPackage ../pkgs/sd_fish_completion {}).src; }
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
          pname = "easel-mode";
          version = "1";
          src = ../pkgs/easel-mode;
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
  xdg.configFile."emacs/init.el".source = ../dotfiles/emacs/init.el;
  xdg.configFile."emacs/early-init.el".source = ../dotfiles/emacs/early-init.el;
  xdg.configFile."emacs/lisp".source = ../dotfiles/emacs/lisp;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
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
