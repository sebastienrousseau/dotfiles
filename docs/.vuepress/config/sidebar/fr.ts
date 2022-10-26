import type { SidebarConfig } from '@vuepress/theme-default'

import { alias } from '../aliases/fr'
import { apropos } from '../about/fr'

export const frSidebar: SidebarConfig = [
  apropos,
  alias,
]
