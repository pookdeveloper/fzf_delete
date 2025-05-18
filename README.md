# fzf_delete

An interactive delete function for Fish shell using [fzf](https://github.com/junegunn/fzf). This plugin allows you to safely and easily delete files and directories from your terminal with a modern, interactive UI.

---

## Features

- Interactive selection of files and directories to delete using `fzf`.
- Confirmation prompts using Fish's built-in `read` command (no external prompt dependencies).
- Supports filtering by files, directories, and hidden items.
- Prevents accidental deletion with clear warnings and confirmation.

---

## Requirements

- [Fish shell](https://fishshell.com/) (v3.0 or newer recommended)
- [fzf](https://github.com/junegunn/fzf)

Install requirements on macOS:

```sh
brew install fzf
```

---

## Installation

### With [Fisher](https://github.com/jorgebucaran/fisher)

```fish
fisher install https://github.com/pookdeveloper/fzf_delete
```

---

### Options

- No parameters: shows all (except hidden)
- `f`: only files
- `d`: only directories
- `a`: all (files and directories)
- `--hidden`: include hidden files/directories
- `--pattern <regex>`: filter items by regex pattern (applied to full path)
- `--exclude <regex>`: exclude items matching regex pattern (applied to full path)
- `--older-than <duration>`: filter items older than duration (e.g., 7d, 3w, 1y)

### Examples

```fish
fzf_delete                        # Shows files and directories (excluding hidden)
fzf_delete d --hidden             # Shows only directories (including hidden)
fzf_delete f --hidden             # Shows only files (including hidden)
fzf_delete --pattern '.*\\.log$'  # Shows only files ending in .log
fzf_delete --older-than 30d --exclude 'backup' # Shows items older than 30 days, excluding paths containing 'backup'
```

---


## Credits

- Inspired by the Fish shell community and modern CLI tools.
- Uses [fzf](https://github.com/junegunn/fzf).

## License

MIT
