import type { SidebarConfig } from '@vuepress/theme-default'

import { aliases } from '../aliases/en'
import { about } from '../about/en'

export const enSidebar: SidebarConfig = [
  about,
  aliases,
]
