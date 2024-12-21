#!/usr/bin/env bash

# Store content in a variable for full display and searching
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

# Display help in a neat format
show_tmux_help() {
    if command -v less > /dev/null; then
        echo "$HELP_CONTENT" | sed 's/|/ - /g' | sed 's/:prefix=Ctrl+b/\n&/' | less -R
    else
        echo "$HELP_CONTENT" | sed 's/|/ - /g' | sed 's/:prefix=Ctrl+b/\n&/'
    fi
}

# Search through commands
search_commands() {
    local search_term="$1"
    local current_section=""
    echo "Searching for: $search_term"
    echo "===================="
    echo

    echo "$HELP_CONTENT" | while IFS= read -r line; do
        if [[ "$line" =~ :prefix=Ctrl\+b$ ]]; then
            # This is a section header
            current_section="${line%%:*}"
        elif [[ "$line" =~ \| ]] && [[ "${line,,}" == *"${search_term,,}"* ]]; then
            # If line contains the search term (case insensitive)
            printf "%-15s %s\n" "[$current_section]" "${line/|/ - }"
        fi
    done | less -R
}

# Main script
main() {
    if [ -n "$TMUX" ]; then
        if [ $# -eq 0 ]; then
            # No arguments, show full help
            show_tmux_help
        else
            # Search mode
            search_commands "$1"
        fi
    else
        echo "This script should be run from within a tmux session."
        exit 1
    fi
}

# Ensure the script runs
main "$@"
