# Zhist

This project is a lightweight and vim-like tui application designed 
to manage and navigate command history for common shells like bash, zsh and fish.

Built using [libvaxis](https://github.com/rockorager/libvaxis) modern tui library.

## Optimizations
1. Use arena allocator for commands (frequents `dupe` calls fragment memory)
2. Use simd instruction when parsing file
3. use stack instead of heap for small file sizes (< 4KB)
4. Use simd instruction for sanitize ascii and key generation
5. New hash function, optimize hash operations
6. Unbuffered IO / syscall overhead (fix)

## Supported shells

- [X] bash
    - history is read from bash history file and refreshed using `history` command.
        (or maybe directly from history output)
      Another option is to use libreadline.
- [ ] zsh
- [ ] fish

## Next steps
- [x] read and parse bash history file into data structure
- [x] clean input
- [x] remove duplicates, keep only last command and add number of duplicates
- [ ] display history entries in scrollable list
- [ ] history navigation with vim-keys
- [ ] execute selected command
- [ ] searching/filtering
- [ ] add some configuration options
- [ ] better logging
- [ ] copy command to clipboard
- [ ] tokenize each command to differentiate between root and arguments
- [ ] select multiple commands and chain them or pipe stuff between them
- [ ] add blacklist feature (those commands will be ignored if found in histfile)
- [ ] modify command and single argument(s)

## Advanced features

- [ ] parallel file's chunks parsing (threads)
- [ ] create, save, list and use custom scripts
- [ ] store history on db (local and cloud (?))
- [ ] sync between devices
- [ ] AI assistant integration
