num=$(xlsclients | sed '/deskcon-server/d' | wc -l)
chars=$(printf "%0.s|" $(seq 0 $num) | head -c -2)
echo "<small>  $chars  </small>"
