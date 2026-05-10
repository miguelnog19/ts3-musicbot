#!/bin/sh
set -e

# Start PulseAudio with a virtual null sink so it works on headless hosts
# with no audio hardware (the most common server scenario).
pulseaudio --start --exit-idle-time=-1 --daemonize=true
pactl load-module module-null-sink sink_name=virtual_out sink_properties=device.description=VirtualOut
pactl set-default-sink virtual_out

echo "PulseAudio started with virtual null sink."

# Start a D-Bus session bus — required by mpv-mpris and playerctl
eval "$(dbus-launch --sh-syntax)"
export DBUS_SESSION_BUS_ADDRESS

# Force Qt to use the xcb (X11) platform plugin — required for TeamSpeak in Xvfb
export QT_QPA_PLATFORM=xcb
# Suppress non-fatal Qt accessibility warnings in headless mode
export NO_AT_BRIDGE=1

exec xvfb-run java \
    --module-path /opt/javafx/lib \
    --add-modules javafx.controls \
    -server \
    -jar /home/botuser/bot/ts3-musicbot.jar \
    "$@"
