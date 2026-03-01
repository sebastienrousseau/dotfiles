function notify-run --description 'Submit a command to pueue and notify when done'
    if test -z "$argv"
        echo "Usage: notify-run <command>"
        return 1
    end
    set -l task_id (pueue add --print-id -- $argv)
    echo "Task $task_id submitted: $argv"
    # Run a background process to wait and notify
    fish -c "pueue wait $task_id; and echo '✅ Task $task_id finished: $argv'" &
    disown
end
