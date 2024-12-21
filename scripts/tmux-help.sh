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

BOLD=$(tput bold)
RESET=$(tput sgr0)
CYAN=$(tput setaf 6)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
MAGENTA=$(tput setaf 5)
BLUE=$(tput setaf 4)
RED=$(tput setaf 1)

section_colors=("$CYAN" "$GREEN" "$YELLOW" "$MAGENTA" "$BLUE" "$RED")

show_tmux_help() {
    local section_index=0
    local formatted_help

    while IFS= read -r line; do
        if [[ "$line" =~ :prefix=Ctrl\+b$ ]]; then
            echo -e "\n${section_colors[section_index]}${BOLD}${line%%:*}${RESET}"
            section_index=$(( (section_index + 1) % ${#section_colors[@]} ))
        else
            echo "$line" | sed 's/|/ - /g'
        fi
    done <<< "$HELP_CONTENT"
}

search_commands() {
    local search_term="$1"
    local current_section=""
    local results=""
    local match_count=0
    local section_index=0

    highlight_term() {
        echo "$1" | sed "s/$search_term/${BOLD}${RED}&${RESET}/Ig"
    }

    while IFS= read -r line; do
        if [[ "$line" =~ :prefix=Ctrl\+b$ ]]; then
            current_section="${section_colors[section_index]}${BOLD}${line%%:*}${RESET}"
            section_index=$(( (section_index + 1) % ${#section_colors[@]} ))
        elif [[ "$line" =~ \| ]] && [[ "$line" =~ $search_term ]]; then
            results+="$(printf "%s\n%s\n" "$current_section" "$(highlight_term "${line/|/ - }")")"
            ((match_count++))
        fi
    done <<< "$HELP_CONTENT"

    if [[ $match_count -eq 0 ]]; then
        echo -e "${RED}No matches found for: ${search_term}${RESET}"
    else
        echo -e "${GREEN}Found $match_count matches for: ${search_term}${RESET}"
        echo -e "==============================\n"
        if command -v less >/dev/null 2>&1; then
            echo -e "$results" | less -RFX
        else
            echo -e "$results"
        fi
    fi
}

check_tmux_env() {
    if [ -z "$TMUX" ]; then
        echo -e "${RED}Error: This script must be run from within a tmux session.${RESET}"
        exit 1
    fi
}

main() {
    check_tmux_env

    if [ $# -eq 0 ]; then
        echo -e "${BOLD}${UNDERLINE}Tmux Help Menu${RESET}"
        echo
        show_tmux_help
    elif [ -z "$1" ]; then
        echo -e "${RED}Error: Search term cannot be empty${RESET}"
        exit 1
    else
        search_commands "$1"
    fi
}

set -e
main "$@"

