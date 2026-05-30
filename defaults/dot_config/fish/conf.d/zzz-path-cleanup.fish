# Deduplicate and prune PATH (runs after all other conf.d files).
# Removes inherited duplicates (nix, system) and non-existent directories.
set -l clean
for p in $PATH
    if test -d "$p"; and not contains -- "$p" $clean
        set -a clean "$p"
    end
end
set -g PATH $clean
