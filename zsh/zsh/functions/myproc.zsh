# myproc: Function to list processes owned by an user
function myproc() { ps "$@" -u "$USER" -o pid,%cpu,%mem,start,time,bsdtime,command; }
