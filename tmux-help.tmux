#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

default_help_key="h"
default_search_key="H"

tmux_get_option() {
  local option=$1
  local default_value=$2
  local option_value=$(tmux show-option -gqv "$option")
  
  if [ -z "$option_value" ]; then 
    echo "$default_value"
  else
    echo "$option_value"
  fi
}

set_bindings() {
  local help_key
  local search_key

  help_key=$(tmux_get_option "@tmux-help-key" "$default_help_key")
  search_key=$(tmux_get_option "@tmux-help-search-key" "$default_search_key")

  # Bind help key to show the help menu
  tmux bind-key "$help_key" run-shell "$CURRENT_DIR/scripts/tmux-help.sh"
  
  # Bind search key to prompt for a search term and run the search script
  tmux bind-key "$search_key" command-prompt -p "Search for:" "run-shell \"$CURRENT_DIR/scripts/tmux-help.sh '%%'"
}

main() {
  set_bindings
  # Ensure scripts are executable
  chmod +x "$CURRENT_DIR/scripts/tmux-help.sh"
}

main