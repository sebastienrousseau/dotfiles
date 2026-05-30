function d --description 'Run dot or docker'
    if command -v dot >/dev/null 2>&1
        dot $argv
    else if command -v docker >/dev/null 2>&1
        docker $argv
    end
end
