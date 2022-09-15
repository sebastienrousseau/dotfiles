# Dotfiles aliases

![Banner representing the Dotfiles Library](/media/dotfiles.svg)

This `copyfile.plugin.zsh` puts the contents of a file in your system clipboard so you can paste it anywhere.

To use, add `copyfile` to your plugins array:

```zsh
plugins=(... copyfile)
```

Then you can run the command `copyfile <filename>` to copy the file named `filename`.