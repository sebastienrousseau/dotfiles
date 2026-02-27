-- Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

return {
  s("def", {
    t("def "),
    i(1, "name"),
    t("("),
    i(2),
    t("):"),
    t({ "", "    " }),
    i(3, "pass"),
  }),
}
