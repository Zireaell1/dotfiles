function brew-age --description 'Outdated Homebrew packages with the date Homebrew shipped each update'
    # Date = the newest commit to the formula/cask file on GitHub
    for kind in formula cask
        for name in (brew outdated --$kind --quiet)
            if test $kind = formula
                set repo homebrew-core
                set dir Formula/(string match -q 'lib*' $name; and echo lib; or string sub -l 1 $name)
            else
                set repo homebrew-cask
                set dir Casks/(string sub -l 1 $name)
            end
            set -l path (string escape --style=url "$dir/$name.rb")
            set -l date (curl -fsS "https://api.github.com/repos/Homebrew/$repo/commits?path=$path&per_page=1" \
                | string match -rg '"date":\s*"([0-9-]{10})' | head -1)
            printf '%-8s %-22s %s\n' $kind $name (test -n "$date"; and echo $date; or echo '?')
        end
    end
end
