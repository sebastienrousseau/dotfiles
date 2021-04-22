# genpwd: Function to generates a strong random password of 20 characters (similar to Apple)
function genpwd() {
    m=$(openssl rand -base64 32 | cut -c 1-6);
    a=$(openssl rand -base64 32 | cut -c 1-6);
    c=$(openssl rand -base64 32 | cut -c 1-6);
    pwd="$m-$a-$c"; 
    echo "[INFO] The password has been copied to the clipboard: $pwd"
    echo "$pwd"| pbcopy | pbpaste;  
}
