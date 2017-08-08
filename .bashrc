
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Source functions that shouldn't be in the git repo
if [ -f ./.private_funcs.sh ]; then
    source ./.private_funcs.sh
fi


#Aliases
# easy of navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ~='cd ~'
alias -- -='cd -'

# easy report
alias ls='ls --color=auto'
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
alias hgrep="fc -El 0 | grep"
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

alias gitk='gitk --all & disown'
alias mp3-dl='youtube-dl --audio-quality 1 --extract-audio --audio-format mp3'
alias timer='echo "Timer started. Stop with Ctrl-D." && date "+%a, %d %b %H:%M:%S" && time cat && date "+%a, %d %b %H:%M:%S"'
alias logout='qdbus org.kde.ksmserver /KSMServer logout 0 3 3'

alias skvm='VBoxManage startvm "Win8"'
alias skoff='VBoxManage controlvm "Win8" poweroff'

alias subl='subl3'
#alias fuck='sudo $(history -p !-1)'
alias fuckthis='sudo systemctl suspend'
#alias yup='yaourt -Syu --aur --noconfirm'
alias yup='bb-wrapper -Syu --aur --noconfirm --build-dir /tmp/bauberbill/'


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


set horizontal-scroll-mode on

# Highlighting inside manpages and elsewhere.
# from paulirish.
export LESS_TERMCAP_mb=$'\E[01;31m'       # begin blinking
export LESS_TERMCAP_md=$'\E[01;38;5;74m'  # begin bold
export LESS_TERMCAP_me=$'\E[0m'           # end mode
export LESS_TERMCAP_se=$'\E[0m'           # end standout-mode
export LESS_TERMCAP_so=$'\E[38;5;246m'    # begin standout-mode - info box
export LESS_TERMCAP_ue=$'\E[0m'           # end underline
export LESS_TERMCAP_us=$'\E[04;38;5;146m' # begin underline

PS1='[\[\033[1;31m\]\u\[\033[0m\]@\[\033[1;30m\]\h\[\033[0m\] \W]\$ '
PS2='> '
PS3='> '
PS4='+ '

PKG_CONFIG_PATH=$PKG_CONFIG_PATH:/usr/local/lib/pkgconfig
export PKG_CONFIG_PATH

export EDITOR=nano


case ${TERM} in
  xterm*|rxvt*|Eterm|aterm|kterm|gnome*)
    PROMPT_COMMAND=${PROMPT_COMMAND:+$PROMPT_COMMAND; }'printf "\033]0;%s@%s:%s\007" "${USER}" "${HOSTNAME%%.*}" "${PWD/#$HOME/\~}"'

    ;;
  screen*)
    PROMPT_COMMAND=${PROMPT_COMMAND:+$PROMPT_COMMAND; }'printf "\033_%s@%s:%s\033\\" "${USER}" "${HOSTNAME%%.*}" "${PWD/#$HOME/\~}"'
    ;;
esac


[ -r /usr/share/bash-completion/bash_completion   ] && . /usr/share/bash-completion/bash_completion
[ -r /usr/share/doc/pkgfile/command-not-found.bash   ] && . /usr/share/doc/pkgfile/command-not-found.bash
[ -r /usr/share/git/completion/git-completion.bash  ] && . /usr/share/git/completion/git-completion.bash

# Load ressources
if xset q &>/dev/null; then
     xrdb -merge ~/.Xresources
fi
