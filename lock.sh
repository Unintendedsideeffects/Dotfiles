#!/bin/bash
#scrot, imagemagick and i3lock needed

scrot /tmp/screen.png
#this is much faster than blurring the image
convert /tmp/screen.png -scale 10% -scale 1000% /tmp/screen.png 

[[ -f $1 ]] && convert /tmp/screen.png $1 -gravity center -composite -matte /tmp/screen.png
i3lock -u -i /tmp/screen.png && echo mem > /sys/power/state
rm /tmp/screen.png
