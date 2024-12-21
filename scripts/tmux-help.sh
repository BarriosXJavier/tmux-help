#!/usr/bin/env bash

HELP_CONTENT=$(cat << 'EOF'
  Sessions:prefix=Ctrl+b
  PREFIX s|List sessions
  PREFIX d|Detach from session
  PREFIX $|Rename session
  PREFIX (|Previous session
  PREFIX )|Next session
  tmux new -s name|Create new named session
  tmux ls|List all sessions
  tmux a -t name|Attach to named session
  Windows:prefix=Ctrl+b
  PREFIX c|Create new window
  PREFIX ,|Rename window
  PREFIX n|Next window
  PREFIX p|Previous window
  PREFIX w|List windows
  PREFIX &|Kill window
  PREFIX 0-9|Switch to window number
  Panes:prefix=Ctrl+b
  PREFIX %|Split pane vertically
  PREFIX "|Split pane horizontally
  PREFIX ←↑↓→|Switch to pane in direction
  PREFIX o|Next pane
  PREFIX ;|Last active pane
  PREFIX x|Kill current pane
  PREFIX space|Toggle pane layouts
  PREFIX z|Toggle pane zoom
  PREFIX {|Move pane left
  PREFIX }|Move pane right
  PREFIX q|Show pane numbers
  PREFIX !|Break pane into new window
  PREFIX +|Create pane with current path
  Copy_Mode:prefix=Ctrl+b
  PREFIX [|Enter copy mode
  Space|Start selection
  Enter|Copy selection
  q|Quit copy mode
  /|Search forward
  ?|Search backward
  n|Next search match
  N|Previous search match
  Misc:prefix=Ctrl+b
  PREFIX t|Show clock
  PREFIX ?|List all keybindings
  PREFIX :|Command prompt
  PREFIX r|Reload tmux config
EOF
)

show_tmux_help() {
    if command -v less >/dev/null 2>&1; then
        echo "$HELP_CONTENT" | sed 's/|/ - /g' | sed 's/:prefix=Ctrl+b/\n&/' | less -RFX
    elif command -v more >/dev/null 2>&1; then
        echo "$HELP_CONTENT" | sed 's/|/ - /g' | sed 's/:prefix=Ctrl+b/\n&/' | more
    else
        echo "$HELP_CONTENT" | sed 's/|/ - /g' | sed 's/:prefix=Ctrl+b/\n&/'
    fi
}

search_commands() {
    local search_term="$1"
    local current_section=""
    local results=""
    local result_count=0

    display_results() {
        if [ "$result_count" -eq 0 ]; then
            echo "No matches found for: $search_term"
            return 0
        else
            echo "Found $result_count matches for: $search_term"
            echo "===================="
            echo
            if command -v less >/dev/null 2>&1; then
                echo "$results" | less -RFX
            else
                echo "$results"
            fi
        fi
    }

    while IFS= read -r line; do
        if [[ "$line" =~ :prefix=Ctrl\+b$ ]]; then
            current_section="${line%%:*}"
        elif [[ "$line" =~ \| ]] && [[ "${line,,}" == *"${search_term,,}"* ]]; then
            results+="$(printf "%-15s %s\n" "[$current_section]" "${line/|/ - }")"
            ((result_count++))
        fi
    done <<< "$HELP_CONTENT"

    display_results
}

check_tmux_env() {
    if [ -z "$TMUX" ]; then
        echo "Error: This script must be run from within a tmux session."
        exit 1
    fi
}

main() {
    check_tmux_env

    if [ $# -eq 0 ]; then
        show_tmux_help
    elif [ -z "$1" ]; then
        echo "Error: Search term cannot be empty"
        exit 1
    else
        search_commands "$1"
    fi
}

set -e
main "$@"

