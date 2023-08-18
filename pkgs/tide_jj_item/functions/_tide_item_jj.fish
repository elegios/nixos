function _tide_item_jj
    if not jj log -r @ --no-graph --template '' 2>/dev/null 1>&2
        return
    end
    # NOTE(vipa, 2023-04-24): We ignore the working copy in everything
    # but the first command, to avoid unnecessary work for jj
    jj --ignore-working-copy log -r @ --no-graph --template 'if(conflict, "conflict")' 2>/dev/null | read -f conflict
    jj --ignore-working-copy log -r @ --no-graph --template 'branches' 2>/dev/null | read -f branches
    jj --ignore-working-copy log -r @ --no-graph --template 'if(empty, "(empty)")' 2>/dev/null | read -f empty
    jj --ignore-working-copy log -r @ --no-graph --template 'if(description, description.first_line(), "(no description)")' | string shorten --max "$tide_jj_truncation_length" | read -f desc
    set -f content (jj --ignore-working-copy st | grep "^[A-Z] " --only-matching | sort | uniq -c | sed 's/^ \\+\([0-9]\\+\) \([A-Z]\).\\+/\\1\\2/')

    _tide_print_item jj $tide_jj_icon' ' (begin
        set_color $tide_jj_color_conflict; echo -ns $conflict' '
        set_color $tide_jj_color_description; echo -ns $desc' '
        set_color $tide_jj_color_branch; echo -ns $branches' '
        set_color $tide_jj_color_content; echo -ns $empty' ' $content' '
        end | string trim
    )
end
