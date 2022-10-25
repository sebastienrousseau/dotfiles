import type { SidebarConfig } from '@vuepress/theme-default'

import { aliases } from '../aliases/en'
import { overview } from '../overview/en'

export const enSidebar: SidebarConfig = [
  overview,
  aliases,
]
