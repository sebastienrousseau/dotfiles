# stopwatch: Function for a stopwatch
function stopwatch(){
  date1=`gdate +%s`;
   while true; do
    echo -ne "$(gdate -u --date @$((`date +%s` - $date1)) +%H:%M:%S)\r";
    sleep 0.1
   done
}
