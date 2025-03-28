# Zhist

This project is a lightweight and vim-like tui application designed 
to manage and navigate command history for common shells like bash, zsh and fish.

Built using [libvaxis](https://github.com/rockorager/libvaxis) modern tui library.

## Supported shells

- [X] bash
    - history is read from bash history file and refreshed using `history` command.
      Another option is to use libreadline.
- [ ] zsh
- [ ] fish

## Basic features

- [ ] history listing
- [ ] history navigation with vim-keys
- [ ] press enter to select command
- [ ] press '/' to match some text against history commands
- [ ] press 'e' to edit the command currently selected
- [ ] select multiple commands and chain them or pipe stuff between them
- [ ] create, save, list and use custom scripts

## Advanced features

- [ ] store history on db (local and cloud (?))
- [ ] sync between devices
- [ ] Ai assistant integration
