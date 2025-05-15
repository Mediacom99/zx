# Zhist
This project is a lightweight and vim-like tui application designed 
to manage and navigate command history for common shells like bash, zsh and fish.

Built using [libvaxis](https://github.com/rockorager/libvaxis) modern tui library.

> [!WARNING]
> Still very much a work in progress

## Try it 
Make sure to have Zig 0.14 installed.
```shell
git clone https://github.com/Mediacom99/zhist.git
cd zhist && git switch develop
zig build run -- <your bash/zsh history file>
```
(q to quit, jk for up/down, enter to select and print to stdout)

## Supported shells
- [ ] bash/zsh
    - [x] history is read from history file and selected command is appended to buffer
    - [ ] add generation of bash/zsh scripts
- [ ] fish

## Simple features and next steps
- [ ] add help menu with keybinds
- [x] display file entries in scrollable list with duplicate count
- [x] history navigation with j/k
- [ ] use indices of start/end command instead of copying command
- [x] execute selected command automatically on zsh
- [x] run zhist with keybind on zsh for even faster flow (it's all about that)
- [ ] modify command and single argument before running
- [ ] searching/filtering
- [ ] add some configuration options
- [ ] better logging
- [ ] copy command to clipboard
- [ ] tokenize each command to differentiate between root and arguments
- [ ] select multiple commands and chain them or pipe stuff between them
- [ ] add blacklist feature (those commands will be ignored if found in histfile)

## Advanced features

- [ ] Use simd instruction when parsing file
- [ ] parallel file's chunks parsing (threads)
- [ ] create, save, list and use custom scripts
- [ ] store history on db (local and cloud (?))
- [ ] sync between devices
- [ ] LLM Integration

# Useful links
- (Semantic versioning)[https://semver.org/]
- [Finite state machine for string representation](https://burntsushi.net/transducers/#fsa-construction)
