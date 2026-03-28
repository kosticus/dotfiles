#!/usr/bin/env bash

# Inspired heavily by repos found in dotfiles.github.io, especially https://github.com/mathiasbynens/dotfiles/

# Load any environment-specific settings
if [ -a ~/.env ]; then
  source ~/.env
fi

# Load in my configs
source ~/.bash/settings.sh
source ~/.bash/functions.sh
source ~/.bash/aliases.sh
source ~/.bash/powerline.sh
source ~/.bash/ralph.sh

# Create directories if they don't exist
mkdir -p "$PROJECTS_DIR"

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

# Homebrew locations: Apple Silicon = /opt/homebrew, Intel Mac = /usr/local. (Not using brew on linux.)
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# pipx and pip user installs go here
if [ -d "$HOME/.local/bin" ]; then
  export PATH="$HOME/.local/bin:$PATH"
fi

# Activate mise for tool version management
if [ "$(command_exists mise)" = 'true' ]; then
  eval "$(mise activate bash)"
fi

## Load brew's shell completion, if installed and shell is interactive
if [ -n "$PS1" ] && [ "$(command_exists brew)" = 'true' ]; then
  if [ -f "$HOMEBREW_PREFIX/etc/bash_completion" ]; then
    source "$HOMEBREW_PREFIX/etc/bash_completion"
  fi
fi

# tk completion (after bash-completion so _init_completion is available)
if [ -f ~/dotfiles/vendor/ticket/completions/ticket-completion.bash ]; then
  source ~/dotfiles/vendor/ticket/completions/ticket-completion.bash
fi

# Used by tmux to load the desired bash executable
export BASH_PATH="$(which bash)"

# Load any environment-specific aliases, paths, etc
if [ -a ~/.bash_profile.local ]; then
  source ~/.bash_profile.local
fi
