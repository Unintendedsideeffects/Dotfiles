#!/bin/sh

alias ls='ls --color=auto'
PS1='\h > '


if [ "$TERM" = "linux" ]; then
  /bin/echo -e "
  \e]P0000000
  \e]P16666cc
  \e]P200779f
  \e]P33b6bcc
  \e]P4217199
  \e]P54068a5
  \e]P6493b8b
  \e]P7a0a0a0
  \e]P8000000
  \e]P96666cc
  \e]PA00779f
  \e]PB3b6bcc
  \e]PC217199
  \e]PD4068a5
  \e]PE493b8b
  \e]PFa0a0a0
  "
  # get rid of artifacts
  clear
fi
