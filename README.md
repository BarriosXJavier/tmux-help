# Tmux Help Plugin

A searchable tmux cheatsheet plugin that provides quick access to tmux commands, keybindings, and options.

## Features

- Organized sections for Sessions, Windows, Panes, and Copy Mode
- Interactive search functionality
- Easy to use keybindings
- Section-based organization

## Installation

### Using TPM (recommended)

Add this line to your `~/.tmux.conf`:

```tmux
set -g @plugin 'BarriosXJavier/tmux-help'
```

Then press `prefix` + `I` to install the plugin.

## Usage

- `prefix + h` - Display full help
- `prefix + H` - Search for specific commands
