
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Source functions that shouldn't be in the git repo
if [ -f ./.private_funcs.sh ]; then
    source ./.private_funcs.sh
fi

mkcd () {
    mkdir -p $1
    cd $1
}

function printpathvar () {
    eval value=\"\$$1\"
    echo "$value" | tr ':' '\n'
    unset value
}

function editpathvar () {
    local tmp=`mktemp`
    echo "Outputting to $tmp..."
    printpathvar $1 > $tmp
    $EDITOR $tmp
    export $1=`cat $tmp | tr '\n' ':'`
    rm $tmp
}

function xwatch () {
    while inotifywait -e close_write $1; do ./$1 "${@:2}"; done
}


function xdirwatch () {
    while inotifywait -r -e close_write .; do $@; done
}

groot() {
    if git_root=$(git rev-parse --show-toplevel 2>/dev/null); then
        pushd "${git_root}"
    fi
}

#Aliases
# easy of navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ~='cd ~'
alias -- -='cd -'
# easy report
alias ip='ip -c=auto'
alias ls='ls -lAGh1vX --group-directories-first --color=auto'
alias l='ls -lFh'
alias ll='ls -la'
alias la='ls -lAFh'
alias lr='ls -tRFh'
alias lf='ls -lFh | grep "^-"'
alias l.f='ls -lFdh .* | grep "^-"'
alias ld='ls -lFh | grep "^d"'
alias l.d='ls -lFdh .* | grep "^d"'
alias dud='du -d 1 -h'
alias duf='du -sh *'
alias fd='find . -type d -name'
alias ff='find . -type f -name'
alias h='history'
alias hgrep="fc -l | grep"
alias lgrep="ls -lFh | grep"
alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -i'
alias rmf='rm -rf'
alias p='ps axo pid,user,pcpu,comm'
alias sgrep='grep -R -n -H -C 5 --exclude-dir={.git,.svn,CVS}'
alias sizeof='wget --no-config --spider'
alias uptime='uptime -p'
alias free='free -h'

#alias ssh='TERM=xterm-color ssh'

alias gitk='gitk --all & disown'
alias mp3-dl='youtube-dl --audio-quality 1 --extract-audio --audio-format mp3'
alias timer='echo "Timer started. Stop with Ctrl-D." && date "+%a, %d %b %H:%M:%S" && time cat && date "+%a, %d %b %H:%M:%S"'
alias logout='qdbus org.kde.ksmserver /KSMServer logout 0 3 3'

alias skvm='VBoxManage startvm "Win8"'
alias skoff='VBoxManage controlvm "Win8" poweroff'

#alias subl='subl3'
#alias fuck='sudo $(history -p !-1)'
alias fuckthis='sudo systemctl suspend'
#alias yup='yaourt -Syu --aur --noconfirm'
#alias yup='bb-wrapper -Syu --aur --noconfirm --build-dir /tmp/bauberbill/ --ignore matlab --ignore gcc5'
alias yup='pikaur -Syua --devel --needed --noconfirm'
alias plyt='mpv --ytdl-format="bestvideo[height<=?1080]+bestaudio/best" $(xclip -o) & disown'

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'

    alias diff='diff --color'
fi

# Additional bashconfig

# Autocorrect typos in path names when using `cd`.
shopt -s cdspell;

# Case-insensitive globbing (used in pathname expansion).
shopt -s nocaseglob;


# Bash attempts to save all lines of a multiple-line command in the same history entry.
# This allows easy re-editing of multi-line commands.
shopt -s cmdhist;

# Check the window size after each command and, if necessary,
# update the values of lines and columns.
shopt -s checkwinsize;

# Gotta tune that bash_history.
export HISTTIMEFORMAT='%F %T '
# Keep history up to date, across sessions, and in realtime.
export HISTCONTROL=ignoredups:erasedups         # no duplicate entries
export HISTSIZE=10000                           # big history (default is 1000)
export HISTFILESIZE=$HISTSIZE                   # big history

shopt -s histappend  # append to history, don't overwrite it
# Save and reload the history after each command finishes. export PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"
# ^ the only downside with this is [up] on the readline will go over all history not just this bash session.

# Disable Ctrl + S
stty -ixon

set horizontal-scroll-mode on

[ -r /usr/share/bash-completion/bash_completion   ] && . /usr/share/bash-completion/bash_completion
[ -r /usr/share/doc/pkgfile/command-not-found.bash   ] && . /usr/share/doc/pkgfile/command-not-found.bash
[ -r /usr/share/git/completion/git-completion.bash  ] && . /usr/share/git/completion/git-completion.bash
[ -r /usr/share/git/completion/git-prompt.sh  ] && . /usr/share/git/completion/git-prompt.sh

# Highlighting inside manpages and elsewhere.
# from paulirish.
export LESS_TERMCAP_mb=$'\E[01;31m'       # begin blinking
export LESS_TERMCAP_md=$'\E[01;38;5;74m'  # begin bold
export LESS_TERMCAP_me=$'\E[0m'           # end mode
export LESS_TERMCAP_se=$'\E[0m'           # end standout-mode
export LESS_TERMCAP_so=$'\E[38;5;246m'    # begin standout-mode - info box
export LESS_TERMCAP_ue=$'\E[0m'           # end underline
export LESS_TERMCAP_us=$'\E[04;38;5;146m' # begin underline

# PS1='[\[\033[1;36m\]\u\[\033[0m\]@\[\033[1;30m\]\h\[\033[0m\] \W]\$ '
# PS1='[\[\033[1;36m\]\u\[\033[0m\] @ \[\033[1;30m\]\h \[\033[0m\]\033[1m\]\w\[\033[0;32m\]$(__git_ps1 " | \033[1m\]%s ")\[\033[0m\]]\n\[\033[0;0m\]└─\[\033[0m\033[1;36m\] \$ ▶\[\033[0m\] '


# case ${TERM} in
#   xterm*|rxvt*|Eterm|aterm|kterm|gnome*)
#     PROMPT_COMMAND=${PROMPT_COMMAND:+$PROMPT_COMMAND; }'printf "\033]0;%s@%s:%s\007" "${USER}" "${HOSTNAME%%.*}" "${PWD/#$HOME/\~}"'

#     ;;
#   screen*)
#     PROMPT_COMMAND=${PROMPT_COMMAND:+$PROMPT_COMMAND; }'printf "\033_%s@%s:%s\033\\" "${USER}" "${HOSTNAME%%.*}" "${PWD/#$HOME/\~}"'
#     ;;
# esac

prompt() {
    PS1="$(powerline-rs --theme=$HOME/.config/powerline/gruvbox.theme --shell bash $?)"
}
PROMPT_COMMAND=prompt


export EDITOR=nvim

function ga_code_search() {
    # alias todo='ga_code_search "TODO\(`whoami`\)"'
    SCREEN_WIDTH=`stty size | awk '{print $2}'`
    SCREEN_WIDTH=$((SCREEN_WIDTH-4))
    # Given a spooky name so you can alias to whatever you want.
    # (cs for codesearch)
    # AG is WAY faster but requires a binary
    # (try brew install the_silver_searcher)
    AG_SEARCH='ag "$1" | grep -v build | sort -k1 | cat -n | cut -c 1-$SCREEN_WIDTH'

    # egrep is installed everywhere and is the default.
    GREP_SEARCH='egrep -nR "$1" * | grep -v build | sort -k1 | cat -n | cut -c 1-$SCREEN_WIDTH'

    SEARCH=$AG_SEARCH

    if [ $# -eq 0 ]; then

        echo "Usage: ga_code_search <search> <index_to_edit>"
        echo ""
        echo "Examples:"
        echo "    ga_code_search TODO"
        echo "    ga_code_search TODO 1"
        echo "    ga_code_search \"TODO\\(graham\\)\""
        echo "    ga_code_search \"TODO\\(graham\\)\" 4"
        echo ""
        return
    fi

    if [ $# -eq 1 ]; then
        # There are no command line argumnets.
        eval $SEARCH
    else
        # arg one should be a line from the output of above.
        LINE="$SEARCH | sed '$2q;d' | awk -F':' '{print +\$2 \" \" \$1}' | awk -F' ' '{print \$3\":\"\$1}'"
        # Modify with your editor here.
        subl `eval $LINE`
    fi
}

alias todo='ga_code_search "TODO\(`whoami`\)"'
alias cs='ga_code_search'

alias low_cpu_run='systemd-run -p CPUQuota="25%" -p AllowedCPUs=0 --scope --uid=$USER --gid=$(id -g $USER) --'
alias low_ram_run='systemd-run -p MemoryLimit=8000M" -p AllowedCPUs=0 --scope --uid=$USER --gid=$(id -g $USER) --'

# Load ressources
if xset q &>/dev/null; then
     xrdb -merge ~/.Xresources
fi

export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:/usr/local/lib/pkgconfig"

# Add yarn to path
PATH=$PATH:~/.yarn/bin

# Add rust binaries to path
PATH=$PATH:~/.cargo/bin

# Add go binaries to path
PATH=$PATH:~/go/bin

# Created by `userpath` on 2020-02-28 17:49:46
export PATH="$PATH:~/.local/bin"
export PATH="$PATH:~/.gem/ruby/3.0.0/bin"
export PATH="$PATH:~/.local/share/gem/ruby/3.0.0/bin"

export PYTHONDONTWRITEBYTECODE=1

export MCFLY_FUZZY=2
export MCFLY_RESULTS=30

source /usr/share/doc/mcfly/mcfly.bash
