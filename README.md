# delete.fish

An interactive delete function for Fish shell using [fzf](https://github.com/junegunn/fzf) and [gum](https://github.com/charmbracelet/gum). This plugin allows you to safely and easily delete files and directories from your terminal with a modern, interactive UI.

---

## Features

- Interactive selection of files and directories to delete using `fzf`.
- Modern confirmation prompts using `gum`.
- Supports filtering by files, directories, and hidden items.
- Prevents accidental deletion with clear warnings and confirmation.

---

## Requirements

- [Fish shell](https://fishshell.com/) (v3.0 or newer recommended)
- [fzf](https://github.com/junegunn/fzf)
- [gum](https://github.com/charmbracelet/gum)

Install requirements on macOS:

```sh
brew install fzf gum
```

---

## Installation

### With [Fisher](https://github.com/jorgebucaran/fisher)

```fish
fisher install yourusername/delete-fish-plugin
```

### Manual

Copy `functions/delete.fish` to your Fish functions directory:

```sh
curl -o ~/.config/fish/functions/delete.fish https://raw.githubusercontent.com/yourusername/delete-fish-plugin/main/functions/delete.fish
```

---

## Usage

```fish
delete                # Show files and directories (excluding hidden)
delete d h            # Show only directories (including hidden)
delete f h            # Show only files (including hidden)
delete a h            # Show files and directories (including hidden)
```

### Options

- No parameters: shows all (except hidden)
- `f`: only files
- `d`: only directories
- `a`: all (files and directories)
- `h`: include hidden files/directories

### Examples

```fish
delete           # Shows files and directories (excluding hidden)
delete d h       # Shows only directories (including hidden)
delete f h       # Shows only files (including hidden)
delete a h       # Shows files and directories (including hidden)
```

---

## Script Documentation

This function shows a list of items in the current directory according to the specified criteria, allows selecting multiple items interactively with `fzf`, and deletes them after confirmation with `gum`.

### Parameters

- **Type**: (first argument)
  - `f` or `F`: Only files
  - `d` or `D`: Only directories
  - `a` or `A`: All (files and directories)
  - If omitted, defaults to all (except hidden)
- **Hidden**: (second argument or first if only `h`)
  - `h` or `H`: Include hidden files/directories

### Behavior

- Lists items according to the chosen type and hidden option.
- Uses `fzf` for interactive multi-selection.
- Shows a warning and asks for confirmation with `gum` before deleting.
- Deletes selected items with `rm -rf` (for directories or all) or `rm -f` (for files).
- Prints a success or error message for each item.

---

## Credits

- Inspired by the Fish shell community and modern CLI tools.
- Uses [fzf](https://github.com/junegunn/fzf) and [gum](https://github.com/charmbracelet/gum).

## License

MIT
