rvnc() {
    ssh -t -L 5900:localhost:5900 $1 'x11vnc -localhost -display :0'
}
