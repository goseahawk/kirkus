# live USB: show the instructions when the console logs in
alias welcome=/usr/local/bin/kirk-welcome
case $(tty 2>/dev/null) in /dev/tty*) /usr/local/bin/kirk-welcome ;; esac
