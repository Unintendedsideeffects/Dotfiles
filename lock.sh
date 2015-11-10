#!/bin/bash
#scrot, imagemagick and i3lock needed
scrot /tmp/screen.png
i3-msg bar mode hide
#using convert to pixellate the screenshot taken, scale and save it to tmp
convert /tmp/screen.png -scale 10% -scale 1000% /tmp/screen.png

[[ -f $1 ]] && convert /tmp/screen.png $1 -gravity center -composite -matte /tmp/screen.png
i3lock -d -i /tmp/screen.png 
#echo mem > /sys/power/state
rm /tmp/screen.png

