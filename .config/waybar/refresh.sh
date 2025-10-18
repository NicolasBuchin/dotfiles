pkill -f "cover_daemon.py"
rm /run/user/1000/waybar-mpris-covers/*
nohup python ~/.config/waybar/cover_daemon.py >/dev/null 2>&1 &
