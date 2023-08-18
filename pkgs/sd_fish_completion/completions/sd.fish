# Completions for the custom Script Directory (sd) script

# These are based on the contents of the Script Directory, so we're reading info from the files.
# The description is taken either from the first line of the file $cmd.help,
# or the first non-shebang comment in the $cmd file.

# Disable file completions
complete -c sd -f

complete -c sd -l "which" -d "Show path to script"
complete -c sd -l "help" -d "List subcommands"
complete -c sd -l "really" -d "Pass next argument to script, not sd"
complete -c sd -l "new" -d "Create a new script" -n "__sd_valid_new_prefix"

set __sd_dir $HOME/sd

if set -q SD_ROOT
  set __sd_dir $SD_ROOT
end

function __sd_subcommand_prefix
  set -l subcmd (string join " " -- $argv)
  set -l line (commandline -pc | sed -r 's/\s+\S*$//')
  string match --quiet "$subcmd" -- "$line"
  return $status
end

function __sd_valid_new_prefix
  set -l tokens (commandline -poc)[2..]
  if test (count $tokens) -eq 0
    return 1
  end

  set -l path $__sd_dir
  for segment in $tokens
    set path $path"/"$segment
    if test -f $path
      return 1
    else if test "$segment" = "--new"
      return 1
    else if test ! -e $path
      return 0
    end
  end
  return 1
end

# Args: directory, rest... is the sequence of subcommands
function __discover_sd
  set -l dir $argv[1]
  set -l seq $argv[2..]

  for f in $dir/*
    # NOTE(vipa, 2023-01-22): For now, assume no .help files
    set -l cmd (basename $f)
    if test $cmd = "template" -o (path extension $f) = ".help"
      continue
    else if test -d $f
      # Directory
      complete -c sd -a "$cmd" -d "$cmd commands" -n "__sd_subcommand_prefix $seq"
      __discover_sd $f $seq (string escape --style=script "$cmd")
    else if test -x $f
      # File
      set -l help
      if test -f $f.help
        set help (head -n1 $f.help)
      else
        set help (sed -nE -e '/^#!/d' -e '/^#/{s/^# *//; p; q;}' "$f")
      end
      complete -c sd -a "$cmd" -d "$help" -n "__sd_subcommand_prefix $seq"
      complete -c sd -l "edit" -d "Open script for editing" -n "__sd_subcommand_prefix $seq $cmd"
      complete -c sd -l "cat" -d "Print script to stdout" -n "__sd_subcommand_prefix $seq $cmd"
      complete -c sd -F -n "__sd_subcommand_prefix $seq $cmd"
    end
  end
end

__discover_sd $__sd_dir sd

# # Create command completions for a subcommand
# # Takes a list of all the subcommands seen so far
# function __list_subcommand
#     # Handles fully nested subcommands
#     set basepath (string join '/' "$HOME/.local/sd" $argv)

#     # Total subcommands
#     # Used so that we can ignore duplicate commands
#     set -l commands
#     for file in (ls -d $basepath/*)
#         set cmd (basename $file .help)
#         set helpfile $cmd.help
#         if [ (basename $file) != "$helpfile" -a "$cmd" != "template" ]
#             set commands $commands $cmd
#         end
#     end

#     # Setup the check for when to show these commands
#     # Basically you need to have seen everything in the path up to this point but not any commands in the current directory.
#     # This will cause problems if you have a command with the same name as a directory parent.
#     set check
#     for arg in $argv
#         set check (string join ' and ' $check "__fish_seen_subcommand_from $arg;")
#     end
#     set check (string join ' ' $check "and not __fish_seen_subcommand_from $commands")

#     # Loop through the files using their full path names.
#     for file in (ls -d $basepath/*)
#         set cmd (basename $file .help)
#         set helpfile $cmd.help
#         if [ (basename $file) = "$helpfile" ]
#             # This is the helpfile, use it for the help statement
#             set help (head -n1 "$file")
#             complete -c sd -a "$cmd" -d "$help" \
#                 -n $check
#         else if test -d "$file"
#             set help "$cmd commands"
#             __list_subcommand $argv $cmd
#             complete -c sd -a "$cmd" -d "$help" \
#                 -n "$check"
#         else
#             set help (sed -nE -e '/^#!/d' -e '/^#/{s/^# *//; p; q;}' "$file")
#             if not test -e "$helpfile"
#                 complete -c sd -a "$cmd" -d "$help" \
#                     -n "$check"
#             end
#         end
#     end
# end

# function __list_commands
#     # commands is used in the completions to know if we've seen the base commands
#     set -l commands

#     # Create a list of commands for this directory.
#     # The list is used to know when to not show more commands from this directory.
#     for file in $argv
#         set cmd (basename $file .help)
#         set helpfile $cmd.help
#         if [ (basename $file) != "$helpfile" ]
#             # Ignore the special commands that take the paths as input.
#             if not contains $cmd cat edit help new which template
#                 set commands $commands $cmd
#             end
#         end
#     end
#     for file in $argv
#         set cmd (basename $file .help)
#         set helpfile $cmd.help
#         if [ (basename $file) = "$helpfile" ]
#             # This is the helpfile, use it for the help statement
#             set help (head -n1 "$file")
#             complete -c sd -a "$cmd" -d "$help" \
#                 -n "not __fish_seen_subcommand_from $commands"
#         else if test -d "$file"
#             # Directory, start recursing into subcommands
#             set help "$cmd commands"
#             __list_subcommand $cmd
#             complete -c sd -a "$cmd" -d "$help" \
#                 -n "not __fish_seen_subcommand_from $commands"
#         else
#             # Script
#             # Pull the help text from the first non-shebang commented line.
#             set help (sed -nE -e '/^#!/d' -e '/^#/{s/^# *//; p; q;}' "$file")
#             if not test -e "$helpfile"
#                 complete -c sd -a "$cmd" -d "$help" \
#                     -n "not __fish_seen_subcommand_from $commands"
#             end
#         end
#     end
# end

# # Hardcode the starting directory
# # __list_commands ~/.local/sd/*
