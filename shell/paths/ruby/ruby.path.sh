#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450) - PNPM Path configuration.

## 🆁🆄🅱🆈 🅷🅾🅼🅴
if [ -z "$RUBY_HOME" ]; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    RUBY_HOME=$(which ruby)
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    RUBY_HOME=" /usr/lib/ruby/2.6.0 "
  fi
  export RUBY_HOME
  export PATH="$RUBY_HOME:$PATH"
fi

## 🅶🅴🅼 🅷🅾🅼🅴
if [ -z "$GEM_HOME" ]; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    GEM_HOME="$(brew --prefix)/Cellar/ruby/3.1.2_1/lib/ruby/gems/3.1.0/"
    GEM_PATH="$(brew --prefix)/Cellar/ruby/3.1.2/lib/ruby/gems/3.1.0/"
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    GEM_HOME=" /usr/lib/ruby/2.6.0 "
    GEM_PATH=" /usr/lib/ruby/2.6.0 "
  fi
  export GEM_HOME
  export GEM_PATH
  export PATH="$GEM_PATH:$PATH"
  export PATH="$GEM_HOME:$PATH"
fi
