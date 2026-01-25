std = "lua51"
globals = { "vim" }
read_globals = { "vim" }

-- Ignore: 122 (read-only field), 611 (trailing whitespace), 631 (line too long)
ignore = { "122", "611", "631" }
max_line_length = 140

files = {
  "dot_config/nvim/**/*.lua",
}
