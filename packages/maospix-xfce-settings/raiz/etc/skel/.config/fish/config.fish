# maospix — fish
set -g fish_greeting
if status is-interactive
    if set -q DISPLAY; or set -q WAYLAND_DISPLAY
        command -q fastfetch; and fastfetch
    end
    set -g fish_color_command 4fd8e8
    set -g fish_color_param d8e1f0
    set -g fish_color_quote b393f5
    set -g fish_color_autosuggestion 4a5878
    set -g fish_color_error f2687e
    set -g fish_color_cwd 4fd8e8
end
