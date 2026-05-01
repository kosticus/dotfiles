#!/usr/bin/env bash
set -e

# Wrapper script for running `qmd mcp` in contexts where the login shell
# environment isn't available (e.g. MCP server subprocesses). Initializes
# Homebrew and mise so that qmd is on PATH regardless of how the process
# was launched.

# Homebrew (needed so mise is findable)
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# mise (provides qmd)
if command -v mise &>/dev/null; then
  eval "$(mise activate bash)"
fi

# n version manager — must come AFTER Homebrew so n's Node takes precedence
# (qmd's native modules are compiled against n's Node, not Homebrew's)
if [ -d "$HOME/n/bin" ]; then
  export PATH="$HOME/n/bin:$PATH"
fi

export NODE_OPTIONS="--no-warnings"
exec qmd mcp
