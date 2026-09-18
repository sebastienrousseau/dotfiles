function powerprofilesctl --description 'Force system python for powerprofilesctl (mise shadows /usr/bin/python3)'
    # /usr/bin/powerprofilesctl uses `#!/usr/bin/env python3`, which resolves
    # to mise's Python — no `gi` module. Force the system interpreter.
    /usr/bin/python3.14 /usr/bin/powerprofilesctl $argv
end
