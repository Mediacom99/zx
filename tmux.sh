#!/usr/bin/env bash

SESSION="zhist-dev"
PROJECT_DIR="/home/mediacom/programming/zhist/"

tmux has-session -t $SESSION 2>/dev/null

if [ $? != 0 ]; then
    tmux new-session -d -s $SESSION -c "$PROJECT_DIR"
    tmux new-window -t $SESSION:1 -n "nvim" -c "$PROJECT_DIR"
    tmux send-keys -t $SESSION:1 'nvim' C-m
    tmux new-window -t $SESSION:2 -n "zsh" -c "$PROJECT_DIR"
fi

tmux attach-session -t $SESSION:1
