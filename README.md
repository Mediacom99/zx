# zx

A terminal shell-history picker written in Zig. It's a personal, early-stage project.

zx reads your bash or zsh history file and shows it as a scrollable list with duplicate counts. Pick a command and it prints to stdout. The project is the first step towards a small set of terminal tools.

> [!WARNING]
> Work in progress. Fuzzy search and fish support aren't built yet.

## Try it

You need Zig 0.14.

```shell
git clone https://github.com/Mediacom99/zx.git
cd zx
zig build run -- <your bash/zsh history file>
```

| Key | Action |
|---|---|
| `j` / `k` | Move down / up |
| `Enter` | Select and print to stdout |
| `q` | Quit |

## Status

**Works today**
- Reads bash/zsh history files
- Scrollable list with duplicate counts
- j/k navigation
- Runs from a zsh keybind and executes the selected command

**Next**
- Search and fuzzy matching, based on [fzf](https://github.com/junegunn/fzf)'s algorithms
- UTF-8 sanitization, normalization and case folding
- Help menu with keybinds
- Shell integration scripts, and fish support
- Editing a command before running it

**Ideas**
- Use indices into the original text to reduce memory use
- SIMD and multithreaded file parsing
- Blacklist for commands to ignore

## Links

- [Finite state machine for string representation](https://burntsushi.net/transducers/#fsa-construction)
