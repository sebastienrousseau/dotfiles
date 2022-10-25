import { enNavbar } from './config/nav';
import { enSidebar } from './config/sidebar';
import { frNavbar } from './config/nav';
import { frSidebar } from './config/sidebar';
import { headers } from './config/head';

module.exports = {
  locales: {
    "/": {
      lang: 'en-GB',
      title: "Dotfiles",
      description: "A set of macOS / Linux and Windows configuration files, simply designed to fit your shell life!",
    },
    "/fr/": {
      lang: "fr-FR",
      title: "Dotfiles",
      description: "Un ensemble de fichiers de configuration macOS/Linux et Windows, simplement conçus pour s'adapter à votre vie de shell !",
    }
  },
  // prettier-ignore
  evergreen: true,
  head: headers,
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
        nav: enNavbar,
        // Custom sidebar values
        sidebar: enSidebar,
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
        nav: frNavbar,
        // Custom sidebar values
        sidebar: frSidebar,
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
