#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.466) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

# Function to generates a strong random password of 27 characters
#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.466) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

# genpwd: Function to generates a strong random password of 20 characters (similar to Apple)
genpwd() {
  # Define the special characters
  SPECIAL="!@#$%^&*()+=[]{};':,.?~"

  # Generate 3 random strings of length 8
  m=$(openssl rand -base64 32 | tr -dc '[:alnum:]' | fold -w 8 | head -n 1 || true)
  a=$(openssl rand -base64 32 | tr -dc '[:alnum:]' | fold -w 8 | head -n 1 || true)
  c=$(openssl rand -base64 32 | tr -dc '[:alnum:]' | fold -w 8 | head -n 1 || true)

  # Choose random positions for the special characters
  m_pos=$((RANDOM % 8))
  a_pos=$((RANDOM % 8))
  c_pos=$((RANDOM % 8))

  # Choose a random special character from the list
  special_char1="${SPECIAL:$((RANDOM % ${#SPECIAL})):1}"
  special_char2="${SPECIAL:$((RANDOM % ${#SPECIAL})):1}"
  special_char3="${SPECIAL:$((RANDOM % ${#SPECIAL})):1}"

  # Combine the strings with the special character to form the password
  pwd="${m:0:${m_pos}}${special_char1}${m:${m_pos}}-${a:0:${a_pos}}${special_char2}${a:${a_pos}}-${c:0:${c_pos}}${special_char3}${c:${c_pos}}"

  echo "[INFO] The password has been copied to the clipboard: ${pwd}"
  echo "${pwd}" | pbcopy | pbpaste || true

}
