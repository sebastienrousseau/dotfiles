import { enNavbar } from './config/nav'; // Import English navbar
import { enSidebar } from './config/sidebar'; // Import English sidebar
import { frNavbar } from './config/nav'; // Import French navbar
import { frSidebar } from './config/sidebar'; // Import French sidebar
import { headers } from './config/head'; // Import Headers for SEO

module.exports = {
  locales: {
    "/": {
      lang: 'en-GB', // English
      title: "Dotfiles",
      description: "A set of macOS / Linux and Windows configuration files, simply designed to fit your shell life!",
    },
    "/fr/": {
      lang: "fr-FR", // French
      title: "Dotfiles",
      description: "Des fichiers de configuration Bash pour macOS, Linux et Windows. Adaptés à vos besoins et pour vous servir.",
    }
  },
  // Enable evergreen browsers support
  evergreen: true,
  // Headers for SEO
  head: headers,
  // Theme default color scheme
  theme: "default-prefers-color-scheme",
  // Theme configuration
  themeConfig: {
    // Search bar configuration
    search: false,
    // Logo configuration
    logo: "/dotfiles.png",
    // The GitHub repo path
    repo: "sebastienrousseau/dotfiles",
    // The label linking to the repo
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
