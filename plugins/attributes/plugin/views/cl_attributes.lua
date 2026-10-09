--- The Attributes tab of the tab menu: `fl_attributes`, the list of a character's attributes
-- grouped by type and category, and `fl_attribute_row`, the line of a single attribute.
-- The same list shows a snapshot of another player's attributes to staff, see
-- `Attributes.open_viewer`. Themes can draw both panels with the `PaintAttributesMenu` and
-- `PaintAttributeRow` methods; a method that returns a value replaces the default look.
-- The colors of the bars are the theme colors 'attribute_level', 'attribute_boost',
-- 'attribute_hindrance' and 'attribute_progress', which have defaults if a theme does not
-- set them.

local default_category = 'attribute.category.other'
local title_background = Color(50, 50, 50, 100)
local default_boost_color = Color(100, 200, 100)
local default_hindrance_color = Color(220, 90, 90)
local type_names = {
  'ui.attributes.type.stat',
  'ui.attributes.type.skill',
  'ui.attributes.type.other'
}

--- Translates a phrase and returns the text alone, without the second value that `t`
-- returns.
-- @param phrase [String phrase or plain text]
-- @param args=nil [Map arguments of the phrase]
-- @return [String]
local function translate(phrase, args)
  local text = t(phrase, args)

  return text
end

--- Formats a number for display: rounded to two decimals, with a plus in front of a
-- positive one if asked for.
-- @param value [Number]
-- @param signed=false [Boolean put a plus in front of a positive number]
-- @return [String]
local function format_number(value, signed)
  value = math.round(tonumber(value) or 0, 2)

  return (signed and value > 0 and '+' or '')..tostring(value)
end

--- Returns the boosts or multipliers of a list that have not run out yet.
-- @param modifiers [List<Map> networked boosts or multipliers, can be nil]
-- @return [List<Map>]
local function active_modifiers(modifiers)
  local cur_time = CurTime()
  local active = {}

  for k, v in pairs(modifiers or {}) do
    if !v.end_time or v.end_time > cur_time then
      table.insert(active, v)
    end
  end

  return active
end

--- Checks whether the row of an attribute has a line of details under its bars: the
-- progress of an attribute that has progress, and the boosts and multipliers.
-- @param attribute_table [AttributeBase]
-- @param data [Map networked data of the attribute, can be nil]
-- @return [Boolean]
local function has_details(attribute_table, data)
  if attribute_table.has_progress != false then
    return true
  end

  return data != nil and (#active_modifiers(data.boosts) > 0 or #active_modifiers(data.multipliers) > 0)
end

--- Describes a list of boosts or multipliers in one line, each with the time it has left
-- if it expires.
-- @param modifiers [List<Map> active boosts or multipliers]
-- @param prefix [String text put in front of every value]
-- @param signed [Boolean put a plus in front of positive values]
-- @return [String]
local function describe_modifiers(modifiers, prefix, signed)
  local cur_time = CurTime()
  local parts = {}

  for k, v in ipairs(modifiers) do
    local text = prefix..format_number(v.value, signed)

    if v.end_time then
      text = translate('ui.attributes.timed', {
        value = text,
        time = Flux.Lang:nice_time(math.max(math.ceil(v.end_time - cur_time), 1))
      })
    end

    table.insert(parts, text)
  end

  return table.concat(parts, ', ')
end

--- The Attributes page of the tab menu (`fl_attributes`): a scrollable list with a header
-- for every type and category of attributes and an `fl_attribute_row` for every attribute
-- that is visible to the player.
-- By default it shows the attributes of the local player and keeps them current while it is
-- open; after `set_snapshot` it shows the data it was given instead, hidden attributes
-- included. `rebuild` recreates the list. Derives from `fl_base_panel`.
local PANEL = {}
PANEL.snapshot = false
PANEL.target = false

--- Creates the scroll panel that holds the list.
function PANEL:Init()
  self.rows = {}
  self.listed = ''

  self.scroll_panel = vgui.Create('DScrollPanel', self)
end

--- Draws the background and the title of the tab, unless the active theme's
-- PaintAttributesMenu method does it. A list that shows a snapshot draws nothing, as it
-- sits inside a frame.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  if Theme.hook('PaintAttributesMenu', self, w, h) == nil and !self.snapshot then
    local text = translate('ui.attributes.title')
    local font = Theme.get_font('main_menu_large')
    local text_w, text_h = util.text_size(text, font)

    DisableClipping(true)
      draw.RoundedBox(0, -4, -4, w + 8, h + 8, title_background)
      draw.textured_rect(
        Theme.get_material('gradient_down'),
        -4,
        -text_h - 4,
        text_w + 8,
        text_h,
        title_background
      )
      draw.SimpleText(text, font, 0, -text_h - 4, color_white)
    DisableClipping(false)
  end
end

--- Keeps the list inside the padding of the panel.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:PerformLayout(w, h)
  local padding = math.scale(8)

  self.scroll_panel:SetPos(padding, padding)
  self.scroll_panel:SetSize(w - padding * 2, h - padding * 2)
end

--- Brings the list up to date twice a second.
function PANEL:Think()
  self.BaseClass.Think(self)

  local cur_time = CurTime()

  if self.next_update and self.next_update > cur_time then return end

  self.next_update = cur_time + 0.5

  self:update()
end

--- Makes the list show the given attribute data of a player instead of the live attributes
-- of the local player. Hidden attributes are listed too. Call `rebuild` afterwards.
-- @param target [Player player the data belongs to]
-- @param attributes [Map attribute data keyed by attribute ID, as `Player:get_attributes`
--   returns it]
function PANEL:set_snapshot(target, attributes)
  self.target = target
  self.snapshot = istable(attributes) and attributes or {}
end

--- Returns the player whose attributes the list shows.
-- @return [Player the player of the snapshot, otherwise the local player]
function PANEL:get_target()
  return self.snapshot and self.target or PLAYER
end

--- Returns the data the list shows for an attribute.
-- @param attribute_id [String]
-- @return [Map level, progress, boosts and multipliers; nil if there is no data]
function PANEL:get_data(attribute_id)
  if self.snapshot then
    return self.snapshot[attribute_id]
  end

  return PLAYER:get_attribute_data(attribute_id)
end

--- Collects the attributes to list, grouped into sections by type and category. Stats come
-- first, then skills, then attributes of no type; the sections of a type are sorted by name
-- and so are the attributes of a section.
-- @return [List<Map> sections: name (String header text) and attributes
--   (List<AttributeBase>)]
function PANEL:get_sections()
  local target = self:get_target()
  local sections = {}
  local by_key = {}

  for k, v in pairs(Attributes.get_stored()) do
    if self.snapshot or Attributes.is_visible(v, target) then
      local order = v.type == ATTRIBUTE_STAT and 1 or v.type == ATTRIBUTE_SKILL and 2 or 3
      local category = v.category or default_category
      local key = order..'/'..category
      local section = by_key[key]

      if !section then
        local name = translate(type_names[order])

        if category != default_category then
          local category_name = translate(category)

          name = order == 3 and category_name or name..' - '..category_name
        end

        section = { name = name, order = order, attributes = {} }
        by_key[key] = section

        table.insert(sections, section)
      end

      table.insert(section.attributes, v)
    end
  end

  table.sort(sections, function(a, b)
    if a.order != b.order then
      return a.order < b.order
    end

    return a.name < b.name
  end)

  for k, v in ipairs(sections) do
    table.sort(v.attributes, function(a, b)
      local name_a, name_b = translate(a.name), translate(b.name)

      if name_a != name_b then
        return name_a < name_b
      end

      return tostring(a.attribute_id) < tostring(b.attribute_id)
    end)
  end

  return sections
end

--- Returns the listed attributes as one string, which changes whenever an attribute
-- appears in the list, disappears from it or moves, or its row gains or loses its line of
-- details.
-- @param sections [List<Map> sections returned by get_sections]
-- @return [String]
function PANEL:get_listed(sections)
  local ids = {}

  for k, v in ipairs(sections) do
    table.insert(ids, v.name)

    for k1, v1 in ipairs(v.attributes) do
      local detailed = has_details(v1, self:get_data(v1.attribute_id))

      table.insert(ids, tostring(v1.attribute_id)..(detailed and '+' or ''))
    end
  end

  return table.concat(ids, ';')
end

--- Recreates the list: a header for every section followed by the rows of its attributes,
-- or a notice if there is no attribute to show.
function PANEL:rebuild()
  local sections = self:get_sections()
  local text_color = Theme.get_color('text')
  local margin = math.scale(4)

  self.rows = {}
  self.listed = self:get_listed(sections)

  self.scroll_panel:Clear()

  if #sections == 0 then
    local notice = self.scroll_panel:Add('DLabel')
    notice:SetText(translate('ui.attributes.empty'))
    notice:SetFont(Theme.get_font('text_small'))
    notice:SetTextColor(text_color)
    notice:SetContentAlignment(5)
    notice:SizeToContents()
    notice:Dock(TOP)
    notice:DockMargin(0, margin * 4, 0, 0)
  end

  for k, v in ipairs(sections) do
    local header = self.scroll_panel:Add('DLabel')
    header:SetText(v.name)
    header:SetFont(Theme.get_font('text_normal'))
    header:SetTextColor(text_color)
    header:SizeToContents()
    header:Dock(TOP)
    header:DockMargin(margin, k == 1 and 0 or margin * 4, 0, margin)

    for k1, v1 in ipairs(v.attributes) do
      local row = self.scroll_panel:Add('fl_attribute_row')
      row:Dock(TOP)
      row:DockMargin(0, 0, 0, margin)
      row:set_attribute(v1)
      row:set_data(self:get_data(v1.attribute_id))
      row:SetTall(row:get_row_height())

      table.insert(self.rows, row)
    end
  end
end

--- Brings the list up to date with the data it shows: rebuilds it if the set of listed
-- attributes has changed, otherwise passes every row its current data.
function PANEL:update()
  if self:get_listed(self:get_sections()) != self.listed then
    self:rebuild()

    return
  end

  for k, v in ipairs(self.rows) do
    if IsValid(v) then
      v:set_data(self:get_data(v:get_attribute().attribute_id))
    end
  end
end

--- Returns the size the tab menu gives this panel when it opens it.
-- @return [Number width, Number height]
function PANEL:get_menu_size()
  return math.scale(960), math.scale(720)
end

vgui.Register('fl_attributes', PANEL, 'fl_base_panel')

--- The line of one attribute in the Attributes tab (`fl_attribute_row`): its icon and
-- name, its level with boosts counted (as the name of the level if the attribute names its
-- levels), a bar that shows where the level lies between the attribute's min and max with
-- the boosted part in another color, a thinner bar for the progress toward the next level,
-- and a line that lists the progress, the boosts and the multipliers with the time each has
-- left. The description of the attribute, of its current level and its effects are the
-- tooltip of the row.
-- Assign the attribute with `set_attribute` and its data with `set_data`. Derives from
-- `fl_base_panel`.
local PANEL = {}
PANEL.attribute_table = false
PANEL.data = false
PANEL.detailed = false
PANEL.name_text = ''
PANEL.value_text = ''
PANEL.boost_text = ''
PANEL.details_text = ''
PANEL.boost = 0
PANEL.level_fraction = 0
PANEL.boosted_fraction = 0
PANEL.progress_fraction = false

--- Picks the color of the line of details, a darker shade of the text color of the theme.
function PANEL:Init()
  self.details_color = Theme.get_color('text'):darken(40)
end

--- Places the image of the attribute's icon in the top left corner of the row.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:PerformLayout(w, h)
  if IsValid(self.image) then
    local padding, size = math.scale(8), math.scale(40)

    self.image:SetPos(padding, padding)
    self.image:SetSize(size, size)
  end
end

--- Draws the row: its background, a FontAwesome icon if the attribute has one, the name and
-- the level, the level and progress bars and the line of details. The active theme's
-- PaintAttributeRow method replaces all of it by returning a value.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  if Theme.hook('PaintAttributeRow', self, w, h) != nil then return end

  draw.RoundedBox(0, 0, 0, w, h, Theme.get_color('background_light'))

  if !self.attribute_table then return end

  local padding = math.scale(8)
  local icon_size = math.scale(40)
  local text_color = Theme.get_color('text')
  local background_color = Theme.get_color('background')
  local boost_color = Theme.get_color('attribute_boost', default_boost_color)
  local hindrance_color = Theme.get_color('attribute_hindrance', default_hindrance_color)
  local font = Theme.get_font('text_normal')
  local x, right = padding, w - padding

  if self.fa_icon then
    FontAwesome:draw(
      self.fa_icon,
      padding + icon_size * 0.5,
      padding + icon_size * 0.5,
      math.scale(28),
      text_color,
      TEXT_ALIGN_CENTER,
      TEXT_ALIGN_CENTER
    )
  end

  if self.fa_icon or IsValid(self.image) then
    x = padding * 2 + icon_size
  end

  draw.SimpleText(self.name_text, font, x, math.scale(6), text_color)

  if self.boost_text != '' then
    local boost_w = draw.SimpleText(
      self.boost_text,
      font,
      right,
      math.scale(6),
      self.boost > 0 and boost_color or hindrance_color,
      TEXT_ALIGN_RIGHT
    )

    right = right - (boost_w or 0) - math.scale(8)
  end

  draw.SimpleText(self.value_text, font, right, math.scale(6), text_color, TEXT_ALIGN_RIGHT)

  local bar_w, bar_y, bar_h = w - padding - x, math.scale(36), math.scale(8)
  local base_w = math.floor(bar_w * self.level_fraction)
  local boosted_w = math.floor(bar_w * self.boosted_fraction)

  draw.box(x, bar_y, bar_w, bar_h, background_color)
  draw.box(x, bar_y, math.min(base_w, boosted_w), bar_h, Theme.get_color('attribute_level', Theme.get_color('accent')))

  if boosted_w > base_w then
    draw.box(x + base_w, bar_y, boosted_w - base_w, bar_h, boost_color)
  elseif boosted_w < base_w then
    draw.box(x + boosted_w, bar_y, base_w - boosted_w, bar_h, hindrance_color)
  end

  if self.progress_fraction then
    local progress_y, progress_h = bar_y + bar_h + math.scale(2), math.scale(4)
    local progress_color = Theme.get_color('attribute_progress', Theme.get_color('accent_light'))

    draw.box(x, progress_y, bar_w, progress_h, background_color)
    draw.box(x, progress_y, math.floor(bar_w * self.progress_fraction), progress_h, progress_color)
  end

  if self.details_text != '' then
    draw.SimpleText(self.details_text, Theme.get_font('text_smaller'), x, math.scale(56), self.details_color)
  end
end

--- Sets the attribute this row shows and creates its icon. An icon that starts with 'fa-'
-- is drawn as a FontAwesome icon, any other is loaded as an image.
-- @param attribute_table [AttributeBase attribute definition]
function PANEL:set_attribute(attribute_table)
  local icon = attribute_table.icon

  self.attribute_table = attribute_table
  self.tooltip_level = nil
  self.fa_icon = nil

  if IsValid(self.image) then
    self.image:safe_remove()
  end

  self.image = nil

  if isstring(icon) and icon != '' then
    if icon:start_with('fa-') then
      self.fa_icon = icon
    else
      self.image = vgui.Create('DImage', self)
      self.image:SetImage(icon)
      self.image:SetMouseInputEnabled(false)
    end
  end

  self:update()
end

--- Returns the attribute this row shows.
-- @return [AttributeBase the attribute definition, or false if none has been set]
function PANEL:get_attribute()
  return self.attribute_table
end

--- Sets the data of the attribute and brings the row up to date with it.
-- @param data [Map level, progress, boosts and multipliers of the attribute; nil or false
--   shows the attribute at its default level]
function PANEL:set_data(data)
  self.data = data or false

  self:update()
end

--- Returns the height the row needs: taller if it has a line of details.
-- @return [Number]
function PANEL:get_row_height()
  return math.scale(self.detailed and 82 or 58)
end

--- Builds the tooltip of the row: the description of the attribute, the description of
-- the given level if the attribute has one, and the effects the attribute lists.
-- @param level [Number level the tooltip is for, boosts counted]
-- @return [String]
function PANEL:build_tooltip(level)
  local attribute_table = self.attribute_table
  local wrap_font, wrap_width = 'DermaDefault', 420
  local lines = {}

  table.Add(lines, util.wrap_text(translate(attribute_table.description), wrap_font, wrap_width) or {})

  local level_description = attribute_table:get_level_description(level)

  if level_description then
    table.insert(lines, '')
    table.Add(lines, util.wrap_text(translate(level_description), wrap_font, wrap_width) or {})
  end

  if istable(attribute_table.effects) then
    local effect_lines = {}

    for k, v in ipairs(attribute_table.effects) do
      if isstring(v.text) and isfunction(v.get_value) then
        table.insert(effect_lines, translate(v.text)..' '..translate(tostring(v.get_value(level))))
      end
    end

    if #effect_lines > 0 then
      table.insert(lines, '')
      table.Add(lines, effect_lines)
    end
  end

  return table.concat(lines, '\n')
end

--- Recalculates what the row shows from its attribute and data: the texts, the fractions
-- of the bars and, when the level has changed, the tooltip. Does nothing if no attribute is
-- set.
function PANEL:update()
  local attribute_table = self.attribute_table

  if !attribute_table then return end

  local data = self.data or {}
  local min, max = attribute_table.min, attribute_table.max
  local base_level = tonumber(data.level) or attribute_table.default
  local boosts = active_modifiers(data.boosts)
  local multipliers = active_modifiers(data.multipliers)
  local boost = 0

  if attribute_table.boostable != false then
    boost = Attributes.sum_boosts(attribute_table, { level = base_level, boosts = boosts })
  end

  local level = base_level + boost
  local level_name = attribute_table:get_level_name(level)
  local range = max - min
  local details = {}

  self.boost = boost
  self.detailed = has_details(attribute_table, data)
  self.name_text = translate(attribute_table.name)

  if attribute_table.hidden then
    self.name_text = self.name_text..' '..translate('ui.attributes.hidden')
  end

  if level_name then
    self.value_text = translate('ui.attributes.level_named', {
      name = translate(level_name),
      level = format_number(level)
    })
  else
    self.value_text = translate('ui.attributes.level', {
      level = format_number(level),
      max = format_number(max)
    })
  end

  self.boost_text = boost != 0 and format_number(boost, true) or ''
  self.level_fraction = range > 0 and math.clamp((base_level - min) / range, 0, 1) or 1
  self.boosted_fraction = range > 0 and math.clamp((level - min) / range, 0, 1) or 1
  self.progress_fraction = false

  if attribute_table.has_progress != false then
    local progress = tonumber(data.progress) or 0
    local total_progress = attribute_table:get_total_progress(base_level)

    if base_level >= max or total_progress <= 0 then
      self.progress_fraction = 0

      table.insert(details, translate('ui.attributes.max_level'))
    else
      self.progress_fraction = math.clamp(progress / total_progress, 0, 1)

      table.insert(details, translate('ui.attributes.progress', {
        progress = format_number(progress),
        total = format_number(total_progress)
      }))
    end
  end

  if #boosts > 0 then
    table.insert(details, translate('ui.attributes.boosts', {
      list = describe_modifiers(boosts, '', true)
    }))
  end

  if #multipliers > 0 then
    table.insert(details, translate('ui.attributes.multipliers', {
      list = describe_modifiers(multipliers, 'x', false)
    }))
  end

  self.details_text = table.concat(details, '    ')

  if self.tooltip_level != level then
    self.tooltip_level = level

    self:SetTooltip(self:build_tooltip(level))
  end
end

vgui.Register('fl_attribute_row', PANEL, 'fl_base_panel')
