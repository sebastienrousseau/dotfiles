---
home: true
title: À propos
subtitle: Un ensemble de fichiers de configuration macOS/Linux et Windows, simplement conçus pour s'adapter à votre vie de shell !
heroImage: /logo.svg
heroText: null
tagline: Un ensemble de fichiers de configuration macOS/Linux et Windows, simplement conçus pour s'adapter à votre vie de shell !
actionText: Commencez →
actionLink: ./a-propos/
features:
  - title: Compatibilité avant tout
    details: Fonctionne sur tous les principaux shells et système d'exploitation. Utilisez-le partout !
  - title: Propulsé par Rust
    details: Profitez de toute la rapidité et la sécurité de Rust pour rendre votre invite de commandes la plus rapide et fiable possible.
  - title: Personnalisable
    details: Tous les petits détails sont personnalisable à votre goût, pour rendre votre invite de commandes aussi légère ou complète que le vous souhaitez.
footer: Licence ISC | Copyright © 2019-présent Contributeurs Starship

#Used for the description meta tag, for SEO
metaTitle: "Les fichiers de configuration Dotfiles"
description: "Un ensemble de fichiers de configuration macOS/Linux et Windows, simplement conçus pour s'adapter à votre vie de shell !"

meta:
  - name: apple-mobile-web-app-status-bar-style
    content: black
  - name: apple-mobile-web-app-title
    content: Les fichiers de configuration Dotfiles v0.2.462
  - name: application-name
    content: Dotfiles v0.2.462
  - name: author
    content: Sebastien Rousseau
  - name: format-detection
    content: telephone=no
  - name: msapplication-tap-highlight
    content: no
  - name: robots
    content: index, follow
  - name: theme-color
    content: "#0F0"
  - name: twitter:card
    content: france - The Dotfiles provides modular configuration files (aliases, functions and paths) built for speed, higher performance, with the aim of helping you have an easy and centralized way to configure your environment and applications.
  - name: twitter:creator
    content: "@wwdseb"
  - name: twitter:description
    content: france - The Dotfiles provides modular configuration files (aliases, functions and paths) built for speed, higher performance, with the aim of helping you have an easy and centralized way to configure your environment and applications.
  - name: twitter:image
    content: https://github.com/sebastienrousseau/dotfiles/raw/master/assets/dotfiles.svg
  - name: twitter:site
    content: "@wwdseb"
  - name: twitter:title
    content: Dotfiles v0.2.462
  - name: twitter:url
    content: https://dotfiles.io/


# Used for the Open Graph image meta tag, for SEO
ogImage: /logo.png
ogImageWidth: 1200
ogImageHeight: 630
ogImageAlt: Dotfiles Logo
ogImageType: image/png
ogImageLocale: en_GB
---


<div class="center">
  <video class="demo-video" muted autoplay loop playsinline>
    <source src="/demo.webm" type="video/webm">
    <source src="/demo.mp4" type="video/mp4">
  </video>
</div>

### Pré-requis

- Une [Nerd Font](https://www.nerdfonts.com/) est installée et activée dans votre terminal.

### Installation

1. Installer le binaire **starship** :

#### Installer la dernière version

   Avec Shell:

   ```sh
   curl -sS https://starship.rs/install.sh | sh
   ```

   Pour mettre à jour Starship, relancez le script ci-dessus. Cela remplacera la version actuelle sans toucher à la configuration de Starship.

#### Installer via le gestionnaire de paquets

   Avec [Homebrew](https://brew.sh/):

   ```sh
   brew install starship
   ```

   With [Winget](https://github.com/microsoft/winget-cli):

   ```powershell
   winget install starship
   ```

1. Ajouter le script d’initialisation au fichier configuration de votre shell:

#### Bash

   Ajouter ce qui suit à la fin de `~/.bashrc`:

   ```sh
   # ~/.bashrc

   eval "$(starship init bash)"
   ```

#### Fish

   Ajoute ce qui suit à la fin de `~/.config/fish/config.fish`:

   ```sh
   # ~/.config/fish/config.fish

   starship init fish | source
   ```

#### Zsh

   Ajouter ce qui suit à la fin de `~/.zshrc`:

   ```sh
   # ~/.zshrc

   eval "$(starship init zsh)"
   ```

#### Powershell

   Ajouter ce qui suit à la fin de `Microsoft.PowerShell_profile.ps1`. Vous pouvez vérifier l'emplacement de ce fichier en regardant la variable `$PROFILE` dans PowerShell. Habituellement, son chemin est `~\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` ou `~/.config/powershell/Microsoft.PowerShell_profile.ps1` sur -Nix.

   ```sh
   Invoke-Expression (&starship init powershell)
   ```

#### Ion

   Ajouter ce qui suit à la fin de `~/.config/ion/initrc`:

   ```sh
   # ~/.config/ion/initrc

   eval $(starship init ion)
   ```

#### Elvish

   ::: warning

   Seul elvish v0.18 ou supérieur est pris en charge.

   :::

   Ajoutez ce qui suit à la fin de `~/.elvish/rc.elv`:

   ```sh
   # ~/.elvish/rc.elv

   eval (starship init elvish)
   ```

#### Tcsh

   Ajoutez ce qui suit à la fin de `~/.tcshrc`:

   ```sh
   # ~/.tcshrc

   eval `starship init tcsh`
   ```

#### Nushell

   ::: warning

   Ceci va changer dans le futur. Seul Nushell v0.61+ est supporté.

   :::

   Add the following to to the end of your Nushell env file (find it by running `$nu.env-path` in Nushell):

   ```sh
   mkdir ~/.cache/starship
   starship init nu | save ~/.cache/starship/init.nu
   ```

   Ajoutez le code suivant à la fin de votre configuration Nushell (trouvez-la en exécutant `$nu.config path`):

   ```sh
   source ~/.cache/starship/init.nu
   ```

#### Xonsh

   Ajouter ce qui suit à la fin de `~/.xonshrc`:

   ```sh
   # ~/.xonshrc

   execx($(starship init xonsh))
   ```

#### Cmd

   Vous devez utiliser [Clink](https://chrisant996.github.io/clink/clink.html) (v1.2.30+) avec Cmd. Ajoutez le code ci-dessous dans un fichier `starship.lua` et placez-le dans le dossier des scripts Clink:

   ```lua
   -- starship.lua

   load(io.popen('starship init cmd'):read("*a"))()
   ```
