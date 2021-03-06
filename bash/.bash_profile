# Inspired heavily by repos found in dotfiles.github.io, specifically https://github.com/mathiasbynens/dotfiles/

# Load this computer's env vars
if [ -a ~/.env ]; then
  source ~/.env
fi

# Determine if we are in OSX (Linux is assumed otherwise)
case "$OSTYPE" in
darwin*) isMac=true ;;
*) isMac=false ;;
esac

# Put readline in vi mode
set -o vi

#
# Exports
#

# Set directory env vars
if [ "$isMac" = true ]; then
  export NOTES_DIR="$HOME/Documents/notes"
  export PROJECTS_DIR="$HOME/Documents/projects"
else
  export NOTES_DIR="$HOME/notes"
  export PROJECTS_DIR="$HOME/projects"
fi

export GIT_EDITOR=vim
export EDITOR=vim

# Don't show zsh warning on Catalina
export BASH_SILENCE_DEPRECATION_WARNING=1

# Bash history, don't store dupes
export HISTCONTROL=ignoredups:erasedups

# Prefer US English and use UTF-8.
export LANG='en_US.UTF-8'
export LC_ALL='en_US.UTF-8'

# Enable persistent REPL history for `node`.
export NODE_REPL_HISTORY=~/.node_history
# Allow 32³ entries; the default is 1000.
export NODE_REPL_HISTORY_SIZE='32768'
# Use sloppy mode by default, matching web browsers.
export NODE_REPL_MODE='sloppy'

# Increase Bash history size. Allow 32³ entries; the default is 500.
export HISTSIZE='32768'
export HISTFILESIZE="${HISTSIZE}"
# Omit duplicates and commands that begin with a space from history.
export HISTCONTROL='ignoreboth'

#
# PATH extensions
#
# Added by n-install (see http://git.io/n-install-repo).
export N_PREFIX="$HOME/n"
[[ :$PATH: == *":$N_PREFIX/bin:"* ]] || PATH+=":$N_PREFIX/bin"

if [ "$isMac" = true ]; then
  export PATH="/usr/local/opt/sqlite/bin:$PATH"
  export PATH="/usr/local/opt/python/libexec/bin:$PATH"
else
  export MANPATH="/home/linuxbrew/.linuxbrew/share/man:$MANPATH"
  export INFOPATH="/home/linuxbrew/.linuxbrew/share/info:$INFOPATH"
  export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
fi

#
# Aliases
#

# Easily fix git conflicts
alias conflicts="git exec vim -p \$(git conflicts)"

# Conveniently edit config files
alias evim='$EDITOR ~/.vimrc'
alias ebash='$EDITOR ~/.bash_profile'
alias egit='$EDITOR ~/.gitconfig'
alias etmux='$EDITOR ~/.tmux.conf'

# Common typos
alias vmi='vim'
alias g="git"
alias gti='git'
alias sl='ls'

# Print out directory tree, but omit node_modules
alias lst='tree -a -I "node_modules|.git|.next|dist|__generated__"'
alias agi='ag --ignore node_modules --ignore dist --ignore coverage --ignore test --ignore tests --ignore __test__ --ignore __mocks__'

# Print each PATH entry on a separate line
alias path='echo -e ${PATH//:/\\n}'

# Easier navigation
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."

# Create directories if they don't exist
mkdir "${NOTES_DIR}" 2>/dev/null
mkdir "${PROJECTS_DIR}" 2>/dev/null

# Shortcuts to custom dirs
alias dotfiles="cd ~/dotfiles"
alias notes="cd $NOTES_DIR"
alias projects="cd $PROJECTS_DIR"
alias downloads="cd ~/Downloads"
alias desktop="cd ~/Desktop"
alias codef="cd ~/Desktop/Code"

# Utility to making a new note (takes a file name)
note() {
  $EDITOR "${NOTES_DIR}/$1"
}

# Print out files with the most commits in the codebase
# Used env vars instead of arguments because I didn't want to mess with flag parsing
hotgitfiles() {
  printf 'USAGE: Can set $AUTHOR_PATTERN, $COMMIT_MSG_PATTERN, $FILE_LIMIT, and $FILE_PATH_PATTERN\n\n'
  # Regex patterns to narrow results
  file_pattern=${FILE_PATH_PATTERN:-'.'}
  author_pattern=${AUTHOR_PATTERN:-'.'}
  commit_msg_pattern=${COMMIT_MSG_PATTERN:-'.'}

  # Number of files to be printed
  file_limit=${FILE_LIMIT:-30}

  # Print out files changed by commit. Apply author and commit message patterns.
  git log --pretty=format: --name-only --author="$author_pattern" --grep="$commit_msg_pattern" |
    # Limit results to those that match the file_pattern
    grep -E "$file_pattern" |
    # Sort results (file names)  so that the duplicates are grouped
    sort |
    # Remove duplicates. Prepend each line with the number of duplicates found
    uniq -c |
    # Sort by number of duplicates (descending)
    sort -rg |
    # Limit results to the specified number
    head -n "$file_limit" |
    awk 'BEGIN {print "commits\t\tfiles"} { print $1 "\t\t" $2; }'
}

# Reload the shell (i.e. invoke as a login shell)
alias reload="exec $SHELL -l"

# Get macOS Software Updates, and update installed Homebrew and npm packages
alias update_global_deps='~/dotfiles/scripts/install.sh'

# Enable aliases to be sudo’ed
alias sudo='sudo '

# Detect which `ls` flavor is in use
if ls --color >/dev/null 2>&1; then # GNU `ls`
  eval "$(dircolors ~/.dir_colors)"
  colorflag="--color"
else # macOS `ls`
  colorflag="-G"
fi

# Always use color output for `ls`
alias ls="command ls -a ${colorflag}"

#
# MISC
#

# Turn on globstar
# shopt -s globstar

# Add tab completion for many Bash commands
if test "$(which brew)"; then
  brewdir=$(brew --prefix)
  if [ -f "$brewdir/etc/bash_completion" ]; then
    source "$brewdir/etc/bash_completion"
  fi
  unset brewdir
fi

unset isMac

source ~/.bash-powerline.sh

# Load this computer's additional configurations
if [ -a ~/.bash_profile.local ]; then
  source ~/.bash_profile.local
fi
