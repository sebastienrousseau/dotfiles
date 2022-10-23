import type { NavbarConfig } from '@vuepress/theme-default'

import { aliases } from './aliases'
import { overview } from './overview'

export const navbar: NavbarConfig = [
  overview,
  aliases,
]