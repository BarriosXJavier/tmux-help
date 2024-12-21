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

if [ -x "$(command -v tput)" ] && [ "$(tput colors)" -ge 256 ]; then
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
    UNDERLINE=$(tput smul)
    CYAN=$'\e[38;2;97;214;214m'    
    GREEN=$'\e[38;2;152;195;121m'   
    YELLOW=$'\e[38;2;229;192;123m'  
    MAGENTA=$'\e[38;2;198;120;221m' 
    BLUE=$'\e[38;2;97;175;239m'     
    RED=$'\e[38;2;224;108;117m'     
    GRAY=$'\e[38;2;92;99;112m'      
else
    # Fallback to basic colors
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
    UNDERLINE=$(tput smul)
    CYAN=$(tput setaf 6)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    MAGENTA=$(tput setaf 5)
    BLUE=$(tput setaf 4)
    RED=$(tput setaf 1)
    GRAY=$(tput setaf 8)
fi

section_colors=("$CYAN" "$GREEN" "$YELLOW" "$MAGENTA" "$BLUE" "$RED")

explanations=(
    "Sessions are persistent workspaces that survive terminal disconnections and system reboots."
    "Windows function like tabs in your browser, allowing multiple terminal views in one session."
    "Panes divide your window into multiple viewports, perfect for monitoring multiple processes."
    "Copy mode lets you scroll, search, and copy text using vim-style keybindings."
    "Additional utilities and commands for managing your tmux environment."
)

print_box() {
    local content="$1"
    local border_color="$2"
    local width="$3"
    local title_line
    local desc_line
    
    title_line=$(echo "$content" | head -n1)
    desc_line=$(echo "$content" | tail -n1)
    
    local padding=$(( (width - ${#title_line}) / 2 ))
    [ $padding -lt 0 ] && padding=0
    
    local top_border="${border_color}╭$(printf '═%.0s' $(seq 1 $width))╮${RESET}"
    local bottom_border="${border_color}╰$(printf '═%.0s' $(seq 1 $width))╯${RESET}"
    
    echo -e "$top_border"
    printf "${border_color}│${RESET}%*s%s%*s${border_color}│${RESET}\n" $padding "" "$title_line" $padding ""
    echo -e "${border_color}│${RESET} ${GRAY}$desc_line${RESET}$(printf '%*s' $((width - ${#desc_line})) '')${border_color}│${RESET}"
    echo -e "$bottom_border"
    echo
}

show_tmux_help() {
    local section_index=0
    local explanation_index=0
    local width=$(tput cols)
    width=$((width - 4))
    
    echo -e "\n${BOLD}${BLUE}┏━━━ Tmux Command Reference ━━━┓${RESET}\n"
    
    while IFS= read -r line; do
        if [[ "$line" =~ :prefix=Ctrl\+b$ ]]; then
            local section_name="${line%%:*}"
            local border_color="${section_colors[section_index]}"
            print_box "$(echo -e "${BOLD}${section_name}${RESET}\n${explanations[explanation_index]}")" "$border_color" "$width"
            section_index=$(( (section_index + 1) % ${#section_colors[@]} ))
            explanation_index=$((explanation_index + 1))
        else
            echo "$line" | sed -E "s/^([^|]+)\|(.*)/${BOLD}\1${RESET} ${GRAY}→${RESET} \2/"
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
        echo "$1" | sed -E "s/($search_term)/${BOLD}${RED}\1${RESET}/gi"
    }
    
    echo -e "\n${BOLD}${BLUE}┏━━━ Search Results ━━━┓${RESET}\n"
    
    while IFS= read -r line; do
        if [[ "$line" =~ :prefix=Ctrl\+b$ ]]; then
            current_section="${section_colors[section_index]}${BOLD}${line%%:*}${RESET}"
            section_index=$(( (section_index + 1) % ${#section_colors[@]} ))
        elif [[ "$line" =~ \| ]] && [[ "$line" =~ $search_term ]]; then
            # Enhanced formatting for search results
            local cmd="${line%%|*}"
            local desc="${line#*|}"
            results+="${current_section}\n"
            results+="$(highlight_term "${BOLD}$cmd${RESET} ${GRAY}→${RESET} $desc")\n\n"
            ((match_count++))
        fi
    done <<< "$HELP_CONTENT"
    
    if [[ $match_count -eq 0 ]]; then
        echo -e "${RED}No matches found for: ${BOLD}$search_term${RESET}"
    else
        echo -e "${GREEN}Found $match_count match(es) for: ${BOLD}$search_term${RESET}"
        echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
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

print_usage() {
    echo -e "${BOLD}Usage:${RESET}"
    echo -e "  ${GREEN}$(basename "$0")${RESET}          - Show all tmux commands"
    echo -e "  ${GREEN}$(basename "$0") ${BLUE}<term>${RESET}    - Search for specific commands"
    echo
}

main() {
    check_tmux_env
    
    if [ $# -eq 0 ]; then
        print_usage
        show_tmux_help
    elif [[ "$1" == "-h" || "$1" == "--help" ]]; then
        print_usage
    elif [[ -n "$1" ]]; then
        search_commands "$1"
    else
        echo -e "${RED}Error: Search term cannot be empty${RESET}"
        print_usage
        exit 1
    fi
}

set -e
main "$@"
