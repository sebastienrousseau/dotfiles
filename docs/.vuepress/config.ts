import { sidebar, navbar, head } from './configs'

module.exports = {
  locales: {
    "/": {
      lang: 'en-GB',
      title: "Dotfiles",
      description: "The minimal, blazing-fast, and infinitely customizable prompt for any shell!",
    },
    "/fr/": {
      lang: "fr-FR",
      title: "Dotfiles",
      description: "L'invite minimaliste, ultra-rapide et personnalisable à l'infini pour n'importe quel shell !",
    }
  },
  // prettier-ignore
  head: head,
  evergreen: true,
  theme: "default-prefers-color-scheme",
  themeConfig: {
    search: false,
    logo: "/dotfiles.png",
    // the GitHub repo path
    repo: "sebastienrousseau/dotfiles",
    // the label linking to the repo
    repoLabel: "GitHub",
    // if your docs are not at the root of the repo:
    docsDir: "docs",
    // defaults to false, set to true to enable
    editLinks: true,
    // locale for edit link text
    locales: {
      "/": {
        // text for the language dropdown
        selectText: "Languages",
        // Aria Label for locale in the dropdown
        ariaLabel: 'Languages',
        // label for this locale in the language dropdown
        label: "English",
        // Custom text for edit link. Defaults to "Edit this page"
        editLinkText: "Edit this page on GitHub",
        // Custom navbar values
        nav: [
          { text: "Aliases", link: "/aliases/", ariaLabel: "Aliases" },
          { text: "Overview", link: "/overview/", ariaLabel: "Overview" }
        ],
        // Custom sidebar values
        sidebar: navbar
      },
      "/fr/": {
        // text for the language dropdown
        selectText: "Langues",
        // Aria Label for locale in the dropdown
        ariaLabel: 'Langues',
        // label for this locale in the language dropdown
        label: "Français",
        // Custom text for edit link. Defaults to "Edit this page"
        editLinkText: "Éditez cette page sur GitHub",
        // Custom navbar values
        nav: [
          { text: "Alias", link: "/fr/aliases/", ariaLabel: "Les alias" },
          { text: "À propos", link: "/fr/overview/", ariaLabel: "À propos" }
        ],
        // Custom sidebar values
        sidebar: navbar
      },
    },
  },
  plugins: [
    [
      "@vuepress/google-analytics",
      {
        ga: "UA-116339011-1",
      },
    ],
    [
      "vuepress-plugin-sitemap",
      {
        hostname: "https://dotfiles.io",
      },
    ],
    ["vuepress-plugin-code-copy", true],
  ],
};