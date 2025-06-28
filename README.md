# zx (Zig Terminal Toolkit)
Lightning-fast, cross-platform terminal tools written in Zig. One toolkit, endless possibilities.

## What is zx ?
zx reimagines essential terminal utilities through the lens of modern performance. 

Starting with a blazing-fast shell history search, zx is evolving into a comprehensive toolkit that 
brings the speed of native code to everyday terminal tasks.

Why another terminal tool? Because we believe developers shouldn't have to choose 
between speed and features.

Written in Zig, zx delivers both—with sub-millisecond response times and a thoughtful 
interface that respects your workflow.

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
- [x] bash/zsh
    - [x] history is read from history file and selected command is appended to buffer
    - [ ] open zx with selectable keybind through zsh hook
- [ ] fish

## Simple features and next steps
- [x] utf8 sanitization, decoding and encoding
- [x] unicode normalization 
- [ ] unicode case folding
- [ ] add help menu with keybinds
- [ ] implement [fzf](https://github.com/junegunn/fzf) fuzzy search algorithms:
    - [x] V1 (fast but not precise)
    - [ ] V2 (slow but precise)
- [x] display file entries in scrollable list with duplicate count
- [x] history navigation with j/k
- [x] execute selected command automatically on zsh (shell hook)
- [x] run zhist with keybind on zsh for even faster flow (it's all about that)
- [ ] modify command and single argument before running
- [ ] add some configuration options
- [ ] better logging
- [ ] copy command to clipboard
- [ ] tokenize each command to differentiate between root and arguments
- [ ] add blacklist feature (those commands will be ignored if found in histfile)
- [ ] command chaining (select multiple commands and add them together with available operators)

## Advanced features

- [ ] create, save, list and use custom scripts
- [ ] use indices of command in original text instead of copying command to reduce memory footprint
- [ ] Use simd instruction when parsing file (?)
- [ ] parallel file's chunks parsing (threads) (?)
- [ ] store history on db (local and cloud (?))
- [ ] sync between devices
- [ ] LLM Integration (why? Everyone wants it...)

# Useful links
- (Semantic versioning)[https://semver.org/]
- [Finite state machine for string representation](https://burntsushi.net/transducers/#fsa-construction)
