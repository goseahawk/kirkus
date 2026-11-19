# live USB: open the graphical start screen once, on the first console; the text instructions
# show whenever it isn't running (and if it can't start).
alias welcome=/usr/local/bin/kirk-welcome
alias gui='startx /usr/local/bin/kirk-live-gui -- -quiet >/tmp/kirk-gui.log 2>&1; /usr/local/bin/kirk-welcome'
case $(tty 2>/dev/null) in
  /dev/tty1)
    if [ -z "$DISPLAY" ] && [ ! -e /run/kirk-gui-started ]; then
      : > /run/kirk-gui-started
      startx /usr/local/bin/kirk-live-gui -- -quiet >/tmp/kirk-gui.log 2>&1 \
        || echo "(The graphical start screen couldn't open; details in /tmp/kirk-gui.log.)"
    fi
    /usr/local/bin/kirk-welcome ;;
  /dev/tty*) /usr/local/bin/kirk-welcome ;;
esac
