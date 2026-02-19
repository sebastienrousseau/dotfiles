local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

return {
  s("todo", { t("TODO("), i(1, "name"), t("): "), i(2) }),
  s("fixme", { t("FIXME("), i(1, "name"), t("): "), i(2) }),
}
