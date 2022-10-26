import type { NavbarConfig } from '@vuepress/theme-default'

import { aliases } from '../aliases/en'
import { about } from '../about/en'

export const enNavbar: NavbarConfig =
  [
    { text: "Aliases", link: "/aliases/", ariaLabel: "Aliases" },
    { text: "About", link: "/about/", ariaLabel: "About" },
  ]
