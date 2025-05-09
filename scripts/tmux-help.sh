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
    local results=""
    local match_count=0
    local section_index=0
    local current_section="${section_colors[0]}${COLORS[BOLD]}General${COLORS[RESET]}"
    local width=$(($(tput cols) - 4))
    
    echo -e "\n${COLORS[BOLD]}${COLORS[BLUE]}┏━━━ Results ━━━┓${COLORS[RESET]}\n"

    if [[ -z "$search_term" ]]; then
        echo -e "${COLORS[RED]}No search term provided${COLORS[RESET]}\n"
        return 0
    fi

    local search_term_lower=$(echo "$search_term" | tr '[:upper:]' '[:lower:]')
    local search_words=($search_term_lower)

    while IFS= read -r line; do
        local line_lower=$(echo "$line" | tr '[:upper:]' '[:lower:]')
        local matched=false

        if [[ "$line" =~ :prefix=Ctrl\+b$ ]]; then
            current_section="${section_colors[section_index]}${COLORS[BOLD]}${line%%:*}${COLORS[RESET]}"
            section_index=$(( (section_index + 1) % ${#section_colors[@]} ))

            for word in "${search_words[@]}"; do
                if [[ "$line_lower" =~ $word ]]; then
                    matched=true
                    break
                fi
            done

            if [[ "$matched" == true ]]; then
                results+="$current_section\n"
                results+="${COLORS[GRAY]}All commands in this section${COLORS[RESET]}\n\n"
                ((match_count++))
            fi
        elif [[ "$line" =~ \| ]]; then
            for word in "${search_words[@]}"; do
                if [[ "$line_lower" =~ $word ]]; then
                    matched=true
                    break
                fi
            done

            if [[ "$matched" == true ]]; then
                [[ "$results" != *"$current_section"* ]] && results+="\n$current_section\n"
                results+="$(format_command "$line")\n"
                ((match_count++))
            fi
        fi
    done <<< "$HELP_CONTENT"

    if ((match_count == 0)); then
        echo -e "${COLORS[RED]}No matches found for: '$search_term'${COLORS[RESET]}\n"
        echo -e "${COLORS[GRAY]}Try terms like:${COLORS[RESET]} ${COLORS[BLUE]}pane window session split switch copy buffer${COLORS[RESET]}"
        return 0
    fi

    if command -v fzf >/dev/null 2>&1 && [[ "$match_count" -gt 5 ]]; then
        echo -e "$results" | fzf --ansi --preview "echo {}" --preview-window=up:10:wrap || echo -e "$results"
    else
        echo -e "$results"
    fi
}

# entry point
display_results "$1"

