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
 tmux kill-server|Kill all sessions and exit
 tmux kill-session -t name|Kill a specific session
 tmux rename-session -t old new|Rename a session
 tmux switch -t name|Switch to another session
 tmux move-session -t dst|Move session to another tmux server
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
Paste_Mode:prefix=Ctrl+b
  PREFIX ]|Paste buffer
  PREFIX =|Choose buffer to paste
  PREFIX #|List buffers
  tmux show-buffer|Show last copied buffer
  tmux save-buffer file|Save buffer to file
  tmux delete-buffer|Delete the top buffer
Misc:prefix=Ctrl+b
 PREFIX t|Show clock
 PREFIX ?|List all keybindings
 PREFIX :|Command prompt
 PREFIX r|Reload tmux config
 PREFIX ~|View messages
EOF
)

declare -A COLORS
if [[ -x $(command -v tput) ]] && [[ $(tput colors) -ge 256 ]]; then
    COLORS=(
        ["BOLD"]=$(tput bold)
        ["RESET"]=$(tput sgr0)
        ["CYAN"]=$'\e[38;2;97;214;214m'
        ["GREEN"]=$'\e[38;2;152;195;121m'
        ["YELLOW"]=$'\e[38;2;229;192;123m'
        ["MAGENTA"]=$'\e[38;2;198;120;221m'
        ["BLUE"]=$'\e[38;2;97;175;239m'
        ["RED"]=$'\e[38;2;224;108;117m'
        ["GRAY"]=$'\e[38;2;92;99;112m'
        ["ORANGE"]=$'\e[38;2;255;160;102m'
        ["SOFT_GREEN"]=$'\e[38;2;170;219;170m'
    )
else
    COLORS=(
        ["BOLD"]=$(tput bold)
        ["RESET"]=$(tput sgr0)
        ["CYAN"]=$(tput setaf 6)
        ["GREEN"]=$(tput setaf 2)
        ["YELLOW"]=$(tput setaf 3)
        ["MAGENTA"]=$(tput setaf 5)
        ["BLUE"]=$(tput setaf 4)
        ["RED"]=$(tput setaf 1)
        ["GRAY"]=$(tput setaf 8)
        ["ORANGE"]=$(tput setaf 3)
        ["SOFT_GREEN"]=$(tput setaf 2)
    )
fi

section_colors=("${COLORS[CYAN]}" "${COLORS[GREEN]}" "${COLORS[YELLOW]}" "${COLORS[MAGENTA]}" "${COLORS[BLUE]}" "${COLORS[RED]}")

declare -A EXPLANATIONS=(
    ["Sessions"]="Sessions survive terminal disconnections and system reboots"
    ["Windows"]="Windows are like tabs, multiple views in one session"
    ["Panes"]="Panes divide windows into multiple viewports"
    ["Copy_Mode"]="Copy mode for scrolling, searching, and copying text"
    ["Paste_Mode"]="Paste mode"
    ["Misc"]="Additional utilities and configuration commands"
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
    
    local top="${border_color}╭$(printf '═%.0s' $(seq 1 $width))╮${COLORS[RESET]}"
    local bottom="${border_color}╰$(printf '═%.0s' $(seq 1 $width))╯${COLORS[RESET]}"
    
    echo -e "$top"
    printf "${border_color}│${COLORS[RESET]} %-${content_width}s ${border_color}│${COLORS[RESET]}\n" "$title"
    
    while IFS= read -r line; do
        printf "${border_color}│${COLORS[RESET]} ${COLORS[GRAY]}%-${content_width}s${COLORS[RESET]} ${border_color}│${COLORS[RESET]}\n" "$line"
    done <<< "$wrapped_desc"
    
    echo -e "$bottom"
    echo
}

format_command() {
    local line="$1"
    if [[ "$line" =~ ^PREFIX ]]; then
        echo "$line" | sed -E "s/PREFIX ([^ |]+)\|(.*)/PREFIX ${COLORS[ORANGE]}\1${COLORS[RESET]} ${COLORS[GRAY]}→${COLORS[RESET]} \2/"
    elif [[ "$line" =~ ^tmux ]]; then
        echo "$line" | sed -E "s/(tmux[^ |]+)\|(.*)/${COLORS[SOFT_GREEN]}\1${COLORS[RESET]} ${COLORS[GRAY]}→${COLORS[RESET]} \2/"
    else
        echo "$line" | sed -E "s/^([^|]+)\|(.*)/${COLORS[ORANGE]}\1${COLORS[RESET]} ${COLORS[GRAY]}→${COLORS[RESET]} \2/"
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
    
    echo -e "\n${COLORS[BOLD]}${COLORS[BLUE]}┏━━━ Results ━━━┓${COLORS[RESET]}\n"
    
    # Check if search term is empty
    if [[ -z "$search_term" ]]; then
        echo -e "${COLORS[RED]}No search term provided${COLORS[RESET]}\n"
        return 0
    fi
    
    while IFS= read -r line; do
        if [[ "$line" =~ :prefix=Ctrl\+b$ ]]; then
            current_section="${section_colors[section_index]}${COLORS[BOLD]}${line%%:*}${COLORS[RESET]}"
            section_index=$(( (section_index + 1) % ${#section_colors[@]} ))
            
            if [[ "${line,,}" =~ ${search_term_lower} ]]; then
                results+="$current_section\n"
                results+="${COLORS[GRAY]}All commands in this section${COLORS[RESET]}\n\n"
                ((match_count++))
            fi
        elif [[ "$line" =~ \| ]] && [[ "${line,,}" =~ ${search_term_lower} ]]; then
            [[ "$results" != *"$current_section"* ]] && results+="\n$current_section\n"
            results+="$(format_command "$line")\n"
            ((match_count++))
        fi
    done <<< "$HELP_CONTENT"
    
    if ((match_count == 0)); then
        echo -e "${COLORS[RED]}No matches found for: '$search_term'${COLORS[RESET]}\n"
        echo -e "${COLORS[GRAY]}Try:${COLORS[RESET]}"
        echo -e "${COLORS[BLUE]}pane window session split switch break kill attach${COLORS[RESET]}"
        return 0
    else
        if command -v fzf >/dev/null 2>&1; then
            # Use fzf for fuzzy search - safely handle potential failures
            echo -e "$results" | fzf --ansi --preview "echo {}" --preview-window=up:10:wrap || {
                # If fzf fails for any reason, fall back to regular output
                echo -e "$results"
            }
        else
            # Fallback if fzf is not installed
            echo -e "$results"
        fi
        return 0
    fi
}

show_help() {
    local section_index=0
    local width=$(($(tput cols) - 4))
    
    echo -e "\n${COLORS[BOLD]}${COLORS[BLUE]}tmux commands${COLORS[RESET]}\n"
    
    while IFS= read -r line; do
        if [[ "$line" =~ :prefix=Ctrl\+b$ ]]; then
            local section_name="${line%%:*}"
            local border_color="${section_colors[section_index]}"
            print_box "$(echo -e "${COLORS[BOLD]}${section_name}${COLORS[RESET]}\n${EXPLANATIONS[$section_name]}")" "$border_color" "$width"
            section_index=$(( (section_index + 1) % ${#section_colors[@]} ))
        else
            format_command "$line"
        fi
    done <<< "$HELP_CONTENT"
}

# Check if running inside tmux
[[ -z "$TMUX" ]] && { echo -e "${COLORS[RED]}Run this inside tmux${COLORS[RESET]}"; exit 1; }

# Main execution
if [[ $# -eq 0 ]]; then
    show_help
else
    display_results "$1"
fi
