import type { NavbarConfig } from '@vuepress/theme-default'

import { aliases } from '../aliases/en'
import { overview } from '../overview/en'

export const enNavbar: NavbarConfig =
  [
    { text: "Aliases", link: "/aliases/", ariaLabel: "Aliases" },
    { text: "Overview", link: "/overview/", ariaLabel: "Overview" }
  ]

// [
//   {
//     ariaLabel: 'Overview',
//     title: 'Overview',
//     path: '/overview/',
//     collapsable: false,
//   },
// ]

// import type { NavbarConfig } from '@vuepress/theme-default'

// import { aliases } from '../aliases'
// import { overview } from '../overview'

// export const navbar: NavbarConfig = [
//   overview,
//   aliases,
// ]
