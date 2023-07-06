if [ -z "${DISPLAY}" ] && [ "${XDG_VTNR}" -eq 1 ]; then
  VBoxClient-all
  exec startx
  xrandr --output "Virtual1" --mode "1920x1080"
fi
