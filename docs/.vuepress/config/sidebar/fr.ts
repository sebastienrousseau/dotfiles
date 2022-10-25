import type { SidebarConfig } from '@vuepress/theme-default'

import { alias } from '../aliases/fr'
import { apropos } from '../overview/fr'

export const frSidebar: SidebarConfig = [
  apropos,
  alias,
]
