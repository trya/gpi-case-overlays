#!/bin/sh

set -e

export DISPLAY=":0"
user=$(who | grep tty | awk '{print $1}')
export XAUTHORITY="/home/$user/.Xauthority"
pserv="unix:/run/user/$(id -u $user)/pulse/native"

internal="DPI-1"
external="HDMI-1"
device="card1-HDMI-A-1"

if [ "$(cat /sys/class/drm/$device/status)" = "connected" ]; then
  while ! xrandr | grep "$external connected" >/dev/null; do sleep 0.1; done
  xrandr --output $external --auto --output $internal --off
  sudo -u $user pactl --server "$pserv" set-default-sink "alsa_output.platform-fef00700.hdmi.hdmi-stereo"
elif [ "$(cat /sys/class/drm/${device}/status)" = "disconnected" ]; then
  xrandr --output ${external} --off --output $internal --auto
  sudo -u $user pactl --server "$pserv" set-default-sink "alsa_output.usb-GeneralPlus_USB_Audio_Device-00.analog-stereo"
fi
