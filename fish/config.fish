if status is-interactive
    # Commands to run in interactive sessions can go here
end

/opt/homebrew/bin/brew shellenv fish | source

fish_add_path -g ~/.local/bin

function fish_greeting
end
