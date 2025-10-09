#
# ~/.bashrc
#

export WINIT_UNIX_BACKEND=wayland
export MOZ_ACCELERATED=1
export MOZ_WEBRENDER=1
export MOZ_DISABLE_HW_ACCELERATION=0
export MOZ_ENABLE_WAYLAND=1
export ELECTRON_OZONE_PLATFORM_HINT=wayland
export ELECTRON_ENABLE_LOGGING=1
export python_cmd="python3.11"

export VISUAL=nvim
export EDITOR=nvim

export PATH="$HOME/.cargo/bin:$PATH"

export EXA_COLORS="\
di=1;38;5;110:\        # directories (light blue-green)
fi=38;5;252:\           # files (soft gray)
ln=1;38;5;146:\         # symlinks (lavender)
ex=1;38;5;114:\         # executables (pastel green)
or=1;38;5;173:\         # orphan links (peach)
*.rs=38;5;180:\         # rust files (light tan)
*.c=38;5;109:\          # c files (soft blue)
*.cpp=38;5;110:\        # cpp files (blue-green)
*.py=38;5;179:\         # python files (pastel yellow)
*.sh=38;5;115:\         # shell scripts (mint green)
*.md=38;5;182"          # markdown (light pink)

alias ls='exa --color=auto -lh --time-style=long-iso --git --group'
alias la='exa --color=auto -lah --time-style=long-iso --git --group'

alias venv='source .venv/bin/activate'

eval "$(ssh-agent -s)" > /dev/null

alias unzipf='f() { d="${1%.zip}"; mkdir -p "$d" && unzip "$1" -d "$d"; }; f'

rsync-parallel() {
    if [ "$#" -ne 2 ]; then
        echo "Usage: rsync_parallel /source/directory /destination/directory"
        return 1
    fi

    source_dir=$1
    dest_dir=$2

    find "$source_dir" -mindepth 1 -maxdepth 1 | xargs -I {} -P 4 rsync -avz {} "$dest_dir"
}

mkdir -p ~/.history
shopt -s histappend

histdir="$HOME/.history"

save_history() {
  local safe_dir
  safe_dir=$(pwd | sed "s|/|_|g")
  export HISTFILE="$histdir/${safe_dir}.history"
  history -a 
  history -c 
  history -r  
}

trap 'save_history' DEBUG

if [ -n "$PROMPT_COMMAND" ]; then 
    PROMPT_COMMAND="$PROMPT_COMMAND; 
$hist_command" 
else 
    PROMPT_COMMAND="$hist_command" 
fi

[[ $- != *i* ]] && return

PS1='[\u@\h \W]\$ '

if [[ -z $DISPLAY ]] then
	Hyprland
fi

