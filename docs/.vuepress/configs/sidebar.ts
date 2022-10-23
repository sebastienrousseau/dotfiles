import type { SidebarConfig } from '@vuepress/theme-default'
import { aliases } from './aliases'
import { overview } from './overview'

export const sidebar = (lang, override = {}): SidebarConfigArray =>
  [
    "", // "Home", which should always have a override
    "overview", // "Overview", which should always have a override
    "aliases", // "Aliases", which should always have a override
  ].map(page => {
    let path = "/";

    if (lang) {
      path += `${lang}/`;
    }

    if (page) {
      path += `${page}/`;
    }

    // If no override is set for current page, let VuePress fallback to page title
    return page in override ? [path, override[page]] : path;
  });