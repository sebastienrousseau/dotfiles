---
description: Les alias Dotfiles vous permettent de créer des raccourcis pour les commandes shell que vous utilisez fréquemment.
lang: fr-FR
metaTitle: Les Alias - Dotfiles (FR)
permalink: /alias/

meta:
  - name: twitter:card
    content: Les alias Dotfiles vous permettent de créer des raccourcis pour les commandes shell que vous utilisez fréquemment.
  - name: twitter:creator
    content: "@wwdseb"
  - name: twitter:description
    content: Les alias Dotfiles vous permettent de créer des raccourcis pour les commandes shell que vous utilisez fréquemment.
  - name: og:title
    content: Les Alias - Dotfiles (FR)
  - name: og:description
    content: Les alias Dotfiles vous permettent de créer des raccourcis pour les commandes shell que vous utilisez fréquemment.
  - name: og:image:alt
    content: Les Alias Dotfiles - Conçus pour s'adapter à votre vie de shell
  - name: og:locale
    content: fr_FR
---

# Les Alias

Les alias vous permettent de créer des raccourcis pour les commandes shell que
vous utilisez fréquemment. Par exemple, au lieu de taper `git status`, vous
pouvez utiliser le raccourci `gst` pour obtenir le même résultat.

C'est un excellent moyen de gagner du temps et de réduire considérablement la
quantité de frappe que vous devez faire lorsque vous utilisez le shell
régulièrement, vous permettant d'être plus productif et efficace.

## 💻 Préréglages

Les Dotfiles disposent d'une collection de préréglages de configuration et de
recettes variées que vous pouvez utiliser pour vous aider à démarrer.

### ❯ Détection automatique du système

Les Dotfiles contiennent une fonction utilitaire pour détecter la version de
`ls` qui est disponible afin d'aider à configurer les variables d'environnement
`LS_COLORS` appropriées à votre système.

La variable d'environnement `LS_COLORS` est par la suite utilisée par la
commande `ls` pour colorer le texte de sortie.

### ❯ Vérifier les alias intégrés

Tapez la commande alias suivante dans votre terminal :

```bash
alias
```

### ❯ Les alias utilitaires de recherche GNU

Les systèmes macOS sont basés sur BSD, plutôt que sur GNU/Linux comme RedHat,
Debian, et Ubuntu. Par conséquent, de nombreux outils de ligne de commande
fournis avec macOS ne sont pas 100% compatibles. Par exemple, la commande `find`
sous macOS ne supporte pas l'option `-printf` qui est utilisée par la commande
`locate`. Cela signifie que la commande `locate` ne fonctionne pas sous macOS.
Pour résoudre ce problème, vous pouvez installer les versions GNU de ces
commandes, qui sont entièrement compatibles avec les versions Linux.

Les utilitaires de recherche GNU (GNU Find Utilities) sont des utilitaires de
base de recherche de répertoire du système d'exploitation GNU. Ces programmes
sont généralement utilisés en conjonction avec d'autres programmes pour fournir
des capacités de recherche de répertoires modulaires et puissantes.

Les outils fournis avec ce pack sont :

- find - recherche de fichiers dans une hiérarchie de répertoires
- locate - lister les fichiers des bases de données qui correspondent à un
  modèle
- updatedb - mettre à jour une base de données de noms de fichiers
- xargs - construire et exécuter des lignes de commande à partir de l'entrée
  standard

Tapez la commande alias suivante dans votre terminal :

```bash
brew install findutils
```

### ❯ Les Alias Dotfiles

Les fichiers fournis dans Dotfiles contiennent quelques alias qui peuvent vous
être utiles. Ceux-ci sont définis dans le répertoire `./dist/lib/aliases` et
sont chargés automatiquement lorsque vous démarrez une nouvelle session shell.

Les alias sont chargés soit par le fichier `~/.bashrc` si vous utilisez le
shell Bash ou dans le fichier `~/.zshrc` si vous utilisez le shell Zsh.

Ils ont été regroupés par catégories logiques :

- [Base][default-url] - Les alias de base disponibles pour tous les utilisateurs
  , quel que soit le shell utilisé.
- [GCloud][gcloud-url] - Les alias pour le Google Cloud SDK,
- [Git][git-url] - Les alias pour le système de contrôle de version Git,
- [Heroku][heroku-url] - Les alias pour la plateforme Heroku,
- [Jekyll][jekyll-url] - Les alias pour le générateur de site statique Jekyll,
- [PnPm][pnpm-url] - Les alias du gestionnaire de paquets PnPM,
- [Subversion][subversion-url] - Les alias pour le système de contrôle de
  version Subversion,
- [Tmux][tmux-url] - Les alias du multiplexeur terminal Tmux.

[default-url]: ./default/
[gcloud-url]: ./gcloud/
[git-url]: ./git/
[heroku-url]: ./heroku/
[jekyll-url]: ./jekyll/
[pnpm-url]: ./pnpm/
[subversion-url]: ./subversion/
[tmux-url]: ./tmux/
