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
  PREFIX %|Split pane horizontally
  PREFIX "|Split pane vertically
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
  PREFIX M-1 to M-5|Set pane layout
  PREFIX C-Up/Down/Left/Right|Resize pane
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
  PREFIX ~|View messages
EOF
)

[[ -x $(command -v tput) ]] && [[ $(tput colors) -ge 256 ]] && {
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
    CYAN=$'\e[38;2;97;214;214m'
    GREEN=$'\e[38;2;152;195;121m'
    YELLOW=$'\e[38;2;229;192;123m'
    MAGENTA=$'\e[38;2;198;120;221m'
    BLUE=$'\e[38;2;97;175;239m'
    RED=$'\e[38;2;224;108;117m'
    GRAY=$'\e[38;2;92;99;112m'
    ORANGE=$'\e[38;2;255;160;102m'
    SOFT_GREEN=$'\e[38;2;170;219;170m'
} || {
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
    CYAN=$(tput setaf 6)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    MAGENTA=$(tput setaf 5)
    BLUE=$(tput setaf 4)
    RED=$(tput setaf 1)
    GRAY=$(tput setaf 8)
    ORANGE=$YELLOW
    SOFT_GREEN=$GREEN
}

section_colors=("$CYAN" "$GREEN" "$YELLOW" "$MAGENTA" "$BLUE" "$RED")

explanations=(
    "Sessions survive terminal disconnections and system reboots"
    "Windows are like tabs, multiple views in one session"
    "Panes divide windows into multiple viewports"
    "Copy mode for scrolling, searching, and copying text"
    "Additional utilities and configuration commands"
)

wrap_text() {
    local text="$1"
    local width="$2"
    local wrapped=""
    local line=""
    
    for word in $text; do
        if [ $((${#line} + ${#word} + 1)) -le "$width" ]; then
            [[ -n "$line" ]] && line+=" "
            line+="$word"
        else
            [[ -n "$wrapped" ]] && wrapped+="\n"
            wrapped+="$line"
            line="$word"
        fi
    done
    [[ -n "$line" ]] && wrapped+="\n$line"
    echo -e "$wrapped"
}

print_box() {
    local content="$1"
    local border_color="$2"
    local width="$3"
    local content_width=$((width - 4))
    
    local title=$(echo "$content" | head -n1)
    local desc=$(echo "$content" | tail -n1)
    local wrapped_desc=$(wrap_text "$desc" "$content_width")
    
    local top="${border_color}╭$(printf '═%.0s' $(seq 1 $width))╮${RESET}"
    local bottom="${border_color}╰$(printf '═%.0s' $(seq 1 $width))╯${RESET}"
    
    echo -e "$top"
    printf "${border_color}│${RESET} %-${content_width}s ${border_color}│${RESET}\n" "$title"
    
    while IFS= read -r line; do
        printf "${border_color}│${RESET} ${GRAY}%-${content_width}s${RESET} ${border_color}│${RESET}\n" "$line"
    done <<< "$wrapped_desc"
    
    echo -e "$bottom"
    echo
}

format_command() {
    local line="$1"
    if [[ "$line" =~ ^PREFIX ]]; then
        echo "$line" | sed -E "s/PREFIX ([^ |]+)\|(.*)/PREFIX ${ORANGE}\1${RESET} ${GRAY}→${RESET} \2/"
    elif [[ "$line" =~ ^tmux ]]; then
        echo "$line" | sed -E "s/(tmux[^ |]+)\|(.*)/${SOFT_GREEN}\1${RESET} ${GRAY}→${RESET} \2/"
    else
        echo "$line" | sed -E "s/^([^|]+)\|(.*)/${ORANGE}\1${RESET} ${GRAY}→${RESET} \2/"
    fi
}

display_results() {
    local search_term="$1"
    local current_section=""
    local results=""
    local match_count=0
    local section_index=0
    local width=$(($(tput cols) - 4))
    local search_term_lower=$(echo "$search_term" | tr '[:upper:]' '[:lower:]')
    
    echo -e "\n${BOLD}${BLUE}┏━━━ Results ━━━┓${RESET}\n"
    
    while IFS= read -r line; do
        if [[ "$line" =~ :prefix=Ctrl\+b$ ]]; then
            current_section="${section_colors[section_index]}${BOLD}${line%%:*}${RESET}"
            section_index=$(( (section_index + 1) % ${#section_colors[@]} ))
            
            if [[ "${line,,}" =~ ${search_term_lower} ]]; then
                results+="$current_section\n"
                results+="${GRAY}All commands in this section${RESET}\n\n"
                ((match_count++))
            fi
        elif [[ "$line" =~ \| ]] && [[ "${line,,}" =~ ${search_term_lower} ]]; then
            [[ "$results" != *"$current_section"* ]] && results+="\n$current_section\n"
            results+="$(format_command "$line")\n"
            ((match_count++))
        fi
    done <<< "$HELP_CONTENT"
    
    if ((match_count == 0)); then
        echo -e "${RED}No matches found${RESET}\n"
        echo -e "${GRAY}Try:${RESET}"
        echo -e "${BLUE}pane window session split switch break kill attach${RESET}"
    else
        if command -v less >/dev/null 2>&1; then
            echo -e "$results" | less -RFX
        else
            echo -e "$results"
        fi
    fi
}

show_help() {
    local section_index=0
    local explanation_index=0
    local width=$(($(tput cols) - 4))
    
    echo -e "\n${BOLD}${BLUE}tmux commands${RESET}\n"
    
    while IFS= read -r line; do
        if [[ "$line" =~ :prefix=Ctrl\+b$ ]]; then
            local section_name="${line%%:*}"
            local border_color="${section_colors[section_index]}"
            print_box "$(echo -e "${BOLD}${section_name}${RESET}\n${explanations[explanation_index]}")" "$border_color" "$width"
            section_index=$(( (section_index + 1) % ${#section_colors[@]} ))
            explanation_index=$((explanation_index + 1))
        else
            format_command "$line"
        fi
    done <<< "$HELP_CONTENT"
}

[[ -z "$TMUX" ]] && { echo -e "${RED}Run this inside tmux${RESET}"; exit 1; }

if [[ $# -eq 0 ]]; then
    show_help
else
    display_results "$1"
fi
