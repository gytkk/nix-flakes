-- zed_onelight.lua — Neovim colorscheme based on Helix's zed_onelight
-- Ported from: https://github.com/helix-editor/helix/blob/master/runtime/themes/zed_onelight.toml

local M = {}

local p = {
  yellow = "#dabb7e",
  red = "#d36151",
  orange = "#d3604f",
  blue = "#5b79e3",
  dark_blue = "#4a62db",
  purple = "#a449ab",
  violet = "#9294be",
  green = "#649f57",
  gold = "#ad6e25",
  cyan = "#3882b7",
  light_black = "#2e323a",
  gray = "#f0f0f2",
  dark_gray = "#f2f2f3",
  light_gray = "#a2a3a7",
  blue_gray = "#e4e8f2",
  faint_gray = "#f7f7f7",
  linenr = "#b0b1b3",
  black = "#383a41",
  white = "#ffffff",
  none = "NONE",
}

function M.setup()
  vim.cmd("hi clear")
  if vim.fn.exists("syntax_on") then
    vim.cmd("syntax reset")
  end
  vim.o.termguicolors = true
  vim.o.background = "light"
  vim.g.colors_name = "zed_onelight"

  local hl = function(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
  end

  -- Editor
  hl("Normal", { fg = p.black, bg = p.white })
  hl("NormalFloat", { fg = p.black, bg = p.dark_gray })
  hl("FloatBorder", { fg = p.light_gray, bg = p.dark_gray })
  hl("Cursor", { fg = p.white, bg = p.dark_blue })
  hl("CursorLine", { bg = p.faint_gray })
  hl("CursorColumn", { bg = p.faint_gray })
  hl("ColorColumn", { bg = p.faint_gray })
  hl("LineNr", { fg = p.linenr })
  hl("CursorLineNr", { fg = p.black, bold = true })
  hl("SignColumn", { bg = p.white })
  hl("VertSplit", { fg = p.gray })
  hl("WinSeparator", { fg = p.gray })
  hl("StatusLine", { fg = p.black, bg = p.gray })
  hl("StatusLineNC", { fg = p.light_gray, bg = p.gray })
  hl("TabLine", { fg = p.light_gray, bg = p.gray })
  hl("TabLineFill", { bg = p.gray })
  hl("TabLineSel", { fg = p.black, bg = p.white, bold = true })
  hl("Pmenu", { fg = p.black, bg = p.dark_gray })
  hl("PmenuSel", { fg = p.white, bg = p.blue })
  hl("PmenuSbar", { bg = p.gray })
  hl("PmenuThumb", { bg = p.light_gray })
  hl("Visual", { bg = p.blue_gray })
  hl("VisualNOS", { bg = p.blue_gray })
  hl("Search", { fg = p.white, bg = p.blue })
  hl("IncSearch", { fg = p.white, bg = p.dark_blue })
  hl("CurSearch", { fg = p.white, bg = p.dark_blue, bold = true })
  hl("MatchParen", { fg = p.dark_blue, underline = true })
  hl("Folded", { fg = p.light_gray, bg = p.faint_gray })
  hl("FoldColumn", { fg = p.linenr, bg = p.white })
  hl("NonText", { fg = p.light_gray })
  hl("SpecialKey", { fg = p.light_gray })
  hl("Whitespace", { fg = p.gray })
  hl("EndOfBuffer", { fg = p.gray })
  hl("Directory", { fg = p.blue })
  hl("Title", { fg = p.blue, bold = true })
  hl("Question", { fg = p.green })
  hl("MoreMsg", { fg = p.green })
  hl("WarningMsg", { fg = p.yellow, bold = true })
  hl("ErrorMsg", { fg = p.red, bold = true })
  hl("ModeMsg", { fg = p.black, bold = true })
  hl("WildMenu", { fg = p.white, bg = p.blue })
  hl("Conceal", { fg = p.light_gray })
  hl("SpellBad", { undercurl = true, sp = p.red })
  hl("SpellCap", { undercurl = true, sp = p.yellow })
  hl("SpellRare", { undercurl = true, sp = p.purple })
  hl("SpellLocal", { undercurl = true, sp = p.cyan })

  -- Diff
  hl("DiffAdd", { bg = "#d4edda" })
  hl("DiffChange", { bg = "#fff3cd" })
  hl("DiffDelete", { bg = "#f8d7da" })
  hl("DiffText", { bg = "#ffeeba", bold = true })
  hl("Added", { fg = p.green })
  hl("Changed", { fg = p.yellow })
  hl("Removed", { fg = p.red })

  -- Syntax (Vim legacy groups)
  hl("Comment", { fg = p.light_gray, italic = true })
  hl("Constant", { fg = p.green })
  hl("String", { fg = p.green })
  hl("Character", { fg = p.green })
  hl("Number", { fg = p.gold })
  hl("Boolean", { fg = p.green })
  hl("Float", { fg = p.gold })
  hl("Identifier", { fg = p.black })
  hl("Function", { fg = p.blue })
  hl("Statement", { fg = p.purple })
  hl("Conditional", { fg = p.purple })
  hl("Repeat", { fg = p.purple })
  hl("Label", { fg = p.black })
  hl("Operator", { fg = p.black })
  hl("Keyword", { fg = p.purple })
  hl("Exception", { fg = p.purple })
  hl("PreProc", { fg = p.purple })
  hl("Include", { fg = p.purple })
  hl("Define", { fg = p.purple })
  hl("Macro", { fg = p.blue })
  hl("PreCondit", { fg = p.purple })
  hl("Type", { fg = p.cyan })
  hl("StorageClass", { fg = p.purple })
  hl("Structure", { fg = p.cyan })
  hl("Typedef", { fg = p.cyan })
  hl("Special", { fg = p.blue })
  hl("SpecialChar", { fg = p.yellow })
  hl("Tag", { fg = p.red })
  hl("Delimiter", { fg = p.black })
  hl("SpecialComment", { fg = p.light_gray, italic = true })
  hl("Debug", { fg = p.red })
  hl("Underlined", { fg = p.cyan, underline = true })
  hl("Ignore", { fg = p.light_gray })
  hl("Error", { fg = p.red, bold = true })
  hl("Todo", { fg = p.purple, bold = true })

  -- Treesitter
  hl("@variable", { fg = p.black })
  hl("@variable.builtin", { fg = p.gold })
  hl("@variable.parameter", { fg = p.black })
  hl("@variable.member", { fg = p.orange })
  hl("@constant", { fg = p.green })
  hl("@constant.builtin", { fg = p.gold })
  hl("@constant.macro", { fg = p.gold })
  hl("@module", { fg = p.black })
  hl("@string", { fg = p.green })
  hl("@string.escape", { fg = p.yellow })
  hl("@string.regexp", { fg = p.yellow })
  hl("@character", { fg = p.green })
  hl("@number", { fg = p.gold })
  hl("@boolean", { fg = p.green })
  hl("@float", { fg = p.gold })
  hl("@function", { fg = p.blue })
  hl("@function.builtin", { fg = p.blue })
  hl("@function.method", { fg = p.blue })
  hl("@function.macro", { fg = p.blue })
  hl("@constructor", { fg = p.blue })
  hl("@keyword", { fg = p.purple })
  hl("@keyword.function", { fg = p.purple })
  hl("@keyword.operator", { fg = p.purple })
  hl("@keyword.return", { fg = p.purple })
  hl("@keyword.import", { fg = p.purple })
  hl("@keyword.conditional", { fg = p.purple })
  hl("@keyword.repeat", { fg = p.purple })
  hl("@keyword.exception", { fg = p.purple })
  hl("@operator", { fg = p.black })
  hl("@punctuation.bracket", { fg = p.black })
  hl("@punctuation.delimiter", { fg = p.black })
  hl("@punctuation.special", { fg = p.black })
  hl("@type", { fg = p.cyan })
  hl("@type.builtin", { fg = p.cyan })
  hl("@type.qualifier", { fg = p.purple })
  hl("@attribute", { fg = p.green })
  hl("@tag", { fg = p.red })
  hl("@tag.attribute", { fg = p.orange })
  hl("@tag.delimiter", { fg = p.black })
  hl("@comment", { fg = p.light_gray, italic = true })
  hl("@markup.heading", { fg = p.orange, bold = true })
  hl("@markup.list", { fg = p.orange })
  hl("@markup.quote", { fg = p.green, italic = true })
  hl("@markup.strong", { bold = true })
  hl("@markup.italic", { italic = true })
  hl("@markup.strikethrough", { strikethrough = true })
  hl("@markup.link.url", { fg = p.cyan, underline = true })
  hl("@markup.link.label", { fg = p.purple })
  hl("@markup.raw", { fg = p.green })
  hl("@markup.raw.markdown_inline", { fg = p.green })

  -- LSP semantic tokens
  hl("@lsp.type.class", { fg = p.cyan })
  hl("@lsp.type.struct", { fg = p.cyan })
  hl("@lsp.type.enum", { fg = p.cyan })
  hl("@lsp.type.enumMember", { fg = p.gold })
  hl("@lsp.type.interface", { fg = p.cyan })
  hl("@lsp.type.parameter", { fg = p.black })
  hl("@lsp.type.property", { fg = p.orange })
  hl("@lsp.type.variable", { fg = p.black })
  hl("@lsp.type.keyword", { fg = p.purple })
  hl("@lsp.type.namespace", { fg = p.black })
  hl("@lsp.type.function", { fg = p.blue })
  hl("@lsp.type.method", { fg = p.blue })
  hl("@lsp.type.macro", { fg = p.blue })
  hl("@lsp.type.decorator", { fg = p.green })
  hl("@lsp.mod.deprecated", { strikethrough = true })

  -- Diagnostics
  hl("DiagnosticError", { fg = p.red })
  hl("DiagnosticWarn", { fg = p.yellow })
  hl("DiagnosticInfo", { fg = p.blue })
  hl("DiagnosticHint", { fg = p.green })
  hl("DiagnosticUnderlineError", { undercurl = true, sp = p.red })
  hl("DiagnosticUnderlineWarn", { undercurl = true, sp = p.yellow })
  hl("DiagnosticUnderlineInfo", { undercurl = true, sp = p.blue })
  hl("DiagnosticUnderlineHint", { undercurl = true, sp = p.green })
  hl("DiagnosticVirtualTextError", { fg = p.red, italic = true })
  hl("DiagnosticVirtualTextWarn", { fg = p.yellow, italic = true })
  hl("DiagnosticVirtualTextInfo", { fg = p.blue, italic = true })
  hl("DiagnosticVirtualTextHint", { fg = p.green, italic = true })

  -- Git signs
  hl("GitSignsAdd", { fg = p.green })
  hl("GitSignsChange", { fg = p.yellow })
  hl("GitSignsDelete", { fg = p.red })

  -- Lualine (auto-detected via lualine theme)
  -- Which-key
  hl("WhichKey", { fg = p.purple })
  hl("WhichKeyGroup", { fg = p.blue })
  hl("WhichKeyDesc", { fg = p.black })
  hl("WhichKeySeparator", { fg = p.light_gray })
  hl("WhichKeyFloat", { bg = p.dark_gray })

  -- Blink.cmp
  hl("BlinkCmpMenu", { fg = p.black, bg = p.dark_gray })
  hl("BlinkCmpMenuBorder", { fg = p.light_gray, bg = p.dark_gray })
  hl("BlinkCmpMenuSelection", { bg = p.blue_gray })
  hl("BlinkCmpLabel", { fg = p.black })
  hl("BlinkCmpLabelMatch", { fg = p.blue, bold = true })
  hl("BlinkCmpKind", { fg = p.purple })
  hl("BlinkCmpGhostText", { fg = p.light_gray, italic = true })

  -- Snacks
  hl("SnacksPickerDir", { fg = p.light_gray })
  hl("SnacksPickerFile", { fg = p.black })
  hl("SnacksPickerMatch", { fg = p.blue, bold = true })
  hl("SnacksPickerPrompt", { fg = p.blue })

  -- Indent guides
  hl("IblIndent", { fg = p.gray })
  hl("IblScope", { fg = p.blue_gray })
  hl("SnacksIndent", { fg = p.gray })
  hl("SnacksIndentScope", { fg = p.blue_gray })
end

return M
