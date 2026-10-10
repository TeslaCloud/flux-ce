--- Font Awesome icons for the interface. Maps the icon names ('fa-plus', 'fa-shield-halved'
-- and so on) to the glyphs of the bundled Font Awesome Free fonts, and draws them as text of
-- any size and color with `FontAwesome:draw`. Three fonts are created from the `CreateFonts`
-- hook: 'FluxFontAwesome' holds the solid icons, 'FluxFontAwesomeRegular' the outlined
-- variants and 'FluxFontAwesomeBrands' the brand logos. An icon is drawn from the solid font
-- unless it only exists as a brand, or the ID carries one of the Font Awesome style prefixes
-- ('far fa-heart' draws the outlined heart, 'fab fa-github' the GitHub logo).
-- The icon data comes from `cl_icons.lua`, which `scripts/update.js` generates from the
-- `@fortawesome/fontawesome-free` npm package together with the TrueType fonts in
-- `content/resource/fonts` of the gamemode, which the package spec sends to clients.
-- @module [FontAwesome]

mod 'FontAwesome'

local glyphs = {}
local styles = {}
local regular = {}
local font_names = {
  solid   = 'FluxFontAwesome',
  regular = 'FluxFontAwesomeRegular',
  brands  = 'FluxFontAwesomeBrands'
}
local prefixes = {
  fas = 'solid',
  far = 'regular',
  fab = 'brands'
}

FontAwesome.version = nil
FontAwesome.fonts   = {}
FontAwesome.hooks   = {}

--- Stores the generated icon data. Called by `cl_icons.lua` once it has been included.
-- @param data [Map with the fields version (String), fonts (Map style to font data with the
--   fields family, weight and file_name), icons (Map icon ID to Number codepoint), styles
--   (Map icon ID to String style of the icons that are not in the solid font) and regular
--   (Map icon ID to true for the icons that also exist in the regular font)]
function FontAwesome.load(data)
  FontAwesome.version = data.version
  FontAwesome.fonts   = data.fonts

  glyphs  = {}
  styles  = data.styles or {}
  regular = data.regular or {}

  for id, codepoint in pairs(data.icons) do
    glyphs[id] = utf8.char(codepoint)
  end
end

--- Creates the fonts that are used to draw the icons.
function FontAwesome.hooks:CreateFonts()
  for style, name in pairs(font_names) do
    local font_data = FontAwesome.fonts[style]

    if font_data then
      Font.create(name, {
        font      = font_data.family,
        extended  = true,
        size      = 16,
        antialias = true,
        weight    = font_data.weight or 400
      })
    end
  end
end

Plugin.add_hooks('FontAwesome', FontAwesome.hooks)

--- Splits an icon ID into the 'fa-' prefixed name and the style that it asks for.
-- Accepts 'plus', 'fa-plus', 'fa plus', 'fas fa-plus', 'far heart' and 'fab fa-github'.
-- @param id [String icon ID]
-- @return [String icon ID with the 'fa-' prefix, String style or nil if none was asked for]
local function parse_id(id)
  local style
  local prefix, name = id:match('^(fa[sbr]?) (.+)$')

  if prefix then
    id    = name
    style = prefixes[prefix]
  end

  if !id:start_with('fa-') then
    id = 'fa-'..id
  end

  return id, style
end

--- Determines if the specified icon exists in the font of the specified style.
-- @param id [String icon ID with the 'fa-' prefix]
-- @param style [String 'solid', 'regular' or 'brands']
-- @return [Boolean]
local function has_style(id, style)
  if style == 'regular' then
    return tobool(regular[id])
  elseif style == 'brands' then
    return styles[id] == 'brands'
  else
    return styles[id] == nil or tobool(regular[id])
  end
end

--- Returns the style an icon is drawn in: the one its ID asks for when the icon exists in
-- that font, the icon's own style otherwise.
-- @param id [String icon ID, such as 'fa-plus' or 'far fa-heart']
-- @return [String 'solid', 'regular' or 'brands'; nil if there is no such icon]
function FontAwesome:get_style(id)
  local name, style = parse_id(id)

  if !glyphs[name] then return end

  if style and has_style(name, style) then
    return style
  end

  return styles[name] or 'solid'
end

--- Returns the name of the font an icon is drawn with, scaled to the specified size.
-- @param id [String icon ID, such as 'fa-plus' or 'fab fa-github']
-- @param size=nil [Number font size, the unscaled font is returned if omitted]
-- @return [String font name, or the solid font if there is no such icon]
function FontAwesome:get_font(id, size)
  return Font.size(font_names[self:get_style(id) or 'solid'], size)
end

--- Returns the glyph of the specified icon.
-- @param id [String icon ID, such as 'fa-plus']
-- @return [String the glyph, or the ID itself if there is no such icon]
function FontAwesome:get(id)
  return glyphs[(parse_id(id))] or id
end

--- Returns the dimensions of the specified icon when drawn at the specified size.
-- @param id [String icon ID, such as 'fa-plus']
-- @param size=16 [Number font size of the icon]
-- @return [Number width, Number height]
function FontAwesome:get_icon_size(id, size)
  return util.text_size(self:get(id), self:get_font(id, size or 16))
end

--- Draws an icon on the screen. The 'fa-' prefix of the ID can be omitted.
-- Draws nothing if there is no such icon.
-- @param id [String icon ID, such as 'fa-plus', 'plus' or 'far fa-heart']
-- @param x [Number]
-- @param y [Number]
-- @param size=16 [Number font size of the icon]
-- @param color=color_white [Color]
-- @param x_align=TEXT_ALIGN_LEFT [Number TEXT_ALIGN enum]
-- @param y_align=TEXT_ALIGN_TOP [Number TEXT_ALIGN enum]
-- @param outline_width=nil [Number draws the icon outlined if specified]
-- @param outline_color=nil [Color]
-- @return [Number width, Number height of the drawn icon; nil if there is no such icon]
function FontAwesome:draw(id, x, y, size, color, x_align, y_align, outline_width, outline_color)
  local glyph = glyphs[(parse_id(id))]

  if !glyph then return end

  local font = self:get_font(id, size or 16)

  color = color or color_white

  if outline_width then
    return draw.SimpleTextOutlined(
      glyph,
      font,
      x,
      y,
      color,
      x_align,
      y_align,
      outline_width,
      outline_color
    )
  else
    return draw.SimpleText(glyph, font, x, y, color, x_align, y_align)
  end
end
