# Zhist
This project is a lightweight and vim-like tui application designed 
to manage and navigate command history for common shells like bash, zsh and fish.

Built using [libvaxis](https://github.com/rockorager/libvaxis) modern tui library.

> [!WARNING]
> Still very much a work in progress

## Try it 
Make sure you have Zig 0.14 installed.
```shell
git clone https://github.com/Mediacom99/zhist.git
cd zhist && git switch develop
zig build run -- <your bash/zsh history file>
```
(q to quit, jk for up/down, enter to select and print to stdout)

## Supported shells
- [ ] bash
    - [ ] history is read from bash history file and refreshed using `history` command.
          (or maybe directly from history output)
      Another option is to use libreadline.
- [ ] zsh
- [ ] fish

## Next steps
- [ ] use indices of start/end command instead of copying command
- [x] display history entries in scrollable list
- [x] history navigation with vim-keys
- [x] execute selected command
- [ ] searching/filtering
- [ ] add some configuration options
- [ ] better logging
- [ ] copy command to clipboard
- [ ] tokenize each command to differentiate between root and arguments
- [ ] select multiple commands and chain them or pipe stuff between them
- [ ] add blacklist feature (those commands will be ignored if found in histfile)
- [ ] modify command and single argument(s)

## Advanced features

- [ ] Use simd instruction when parsing file
- [ ] parallel file's chunks parsing (threads)
- [ ] create, save, list and use custom scripts
- [ ] store history on db (local and cloud (?))
- [ ] sync between devices
- [ ] AI assistant integration

# Useful links
(Semantic versioning)[https://semver.org/]

[Finite state machine for string representation](https://burntsushi.net/transducers/#fsa-construction)

