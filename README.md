# Zhist

This project is a lightweight and vim-like tui application designed 
to manage and navigate command history for common shells like bash, zsh and fish.

Built using [libvaxis](https://github.com/rockorager/libvaxis) modern tui library.

## Supported shells

- [X] bash
    - history is read from bash history file and refreshed using `history` command.
        (or maybe directly from history output)
      Another option is to use libreadline.
- [ ] zsh
- [ ] fish

## Next steps
- [ ] read and parse bash history file into data structure
- [ ] add some configuration options
- [ ] better logging ?
- [ ] display history entries in scrollable list
- [ ] history navigation with vim-keys
- [ ] searching/filtering
- [ ] copy to clipboard / execute selected command
- [ ] select multiple commands and chain them or pipe stuff between them

## Advanced features

- [ ] create, save, list and use custom scripts
- [ ] store history on db (local and cloud (?))
- [ ] sync between devices
- [ ] AI assistant integration
