import type { NavbarConfig } from '@vuepress/theme-default'

import { alias } from '../aliases/fr'
import { apropos } from '../overview/fr'

export const frNavbar: NavbarConfig =
  [
    { text: "Alias", link: "/fr/alias/", ariaLabel: "Les alias" },
    { text: "À propos", link: "/fr/a-propos/", ariaLabel: "À propos" }
  ]
