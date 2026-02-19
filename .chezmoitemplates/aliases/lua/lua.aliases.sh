# shellcheck shell=bash
# Lua REPL helpers

if command -v lua >/dev/null; then
  alias lua-repl='lua'
fi

if command -v luajit >/dev/null; then
  alias luajit-repl='luajit'
fi

if command -v lua5.1 >/dev/null; then
  alias lua51='lua5.1'
fi
