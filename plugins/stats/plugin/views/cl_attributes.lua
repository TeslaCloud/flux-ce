--- The attribute list that shows staff the attributes and skills of a character:
-- `fl_attributes`, the list of a character's attributes grouped by category followed by its
-- skills grouped by key stat, and `fl_attribute_row`, the line of a single attribute or
-- skill. `Attributes.open_viewer` puts the list into a window with a snapshot of another
-- player's attributes and skills, which the `attribute list` command sends. Themes
-- can draw both panels with the `PaintAttributesMenu` and `PaintAttributeRow` methods; a
-- method that returns a value replaces the default look. The colors of the bars are the
-- theme colors 'attribute_level', 'attribute_boost' and 'attribute_hindrance', which have
-- defaults if a theme does not set them.

local math_clamp = math.clamp
local math_floor = math.floor
local math_scale = math.scale
local draw_box = draw.box
local draw_simple_text = draw.SimpleText
local get_color = Theme.get_color

local default_category = 'attribute.category.other'
local default_boost_color = Color(98, 200, 130)
local default_hindrance_color = Color(228, 92, 104)

--- Translates a phrase and returns the text alone, without the second value that `t`
-- returns.
-- @param phrase [String phrase or plain text]
-- @param args=nil [Map arguments of the phrase]
-- @return [String]
local function translate(phrase, args)
  local text = t(phrase, args)

  return text
end

local function format_number(value, signed)
  value = math.round(tonumber(value) or 0, 2)

  return (signed and value > 0 ? '+' : '')..tostring(value)
end

local function active_boosts(boosts)
  local cur_time = CurTime()
  local active = {}

  if boosts then
    for _, boost in pairs(boosts) do
      if !boost.end_time or boost.end_time > cur_time then
        active[#active + 1] = boost
      end
    end
  end

  return active
end

local function has_details(data)
  return data != nil and #active_boosts(data.boosts) > 0
end

local function describe_boosts(boosts)
  local cur_time = CurTime()
  local parts = {}

  for _, boost in ipairs(boosts) do
    local text = format_number(boost.value, true)

    if boost.end_time then
      text = translate('ui.attributes.timed', {
        value = text,
        time = Flux.Lang:nice_time(math.max(math.ceil(boost.end_time - cur_time), 1))
      })
    end

    parts[#parts + 1] = text
  end

  return table.concat(parts, ', ')
end

--- Sorts attribute or skill definitions by their translated names, and by their IDs when
-- the names are the same.
-- @param list [List<AttributeBase/SkillBase> sorted in place]
-- @param translated_names [Map translated names keyed by definition]
local function sort_definitions(list, translated_names)
  table.sort(list, function(a, b)
    local name_a, name_b = translated_names[a], translated_names[b]

    if name_a != name_b then
      return name_a < name_b
    end

    return tostring(a.attribute_id or a.skill_id) < tostring(b.attribute_id or b.skill_id)
  end)
end

--- The attribute list (`fl_attributes`): a scrollable list with a header for every category
-- of attributes and every key stat of skills, and an `fl_attribute_row` for every attribute
-- and skill that is visible to the player.
-- By default it shows the attributes and skills of the local player and keeps them current
-- while it is open; after `set_snapshot` it shows the data it was given instead, hidden
-- attributes and skills included. `rebuild` recreates the list. Derives from
-- `fl_base_panel`.
local PANEL = {}
PANEL.snapshot = false
PANEL.skill_snapshot = false
PANEL.target = false

--- Creates the scroll panel that holds the list.
function PANEL:Init()
  self.rows = {}
  self.listed = ''

  self.scroll_panel = vgui.Create('DScrollPanel', self)
end

--- Draws the card and the title of the list, unless the active theme's PaintAttributesMenu
-- method does it. A list that shows a snapshot draws nothing, as it sits inside a frame.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  if Theme.hook('PaintAttributesMenu', self, w, h) == nil and !self.snapshot then
    Theme.hook('PaintSurface', self, w, h)
    Theme.hook('PaintSectionTitle', self, translate('ui.attributes.title'), w, h)
  end
end

--- Keeps the list inside the padding of the panel.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:PerformLayout(w, h)
  local padding = math_scale(self.snapshot ? 0 : 12)

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

--- Makes the list show the given attribute data and skill ranks of a player instead of the
-- live attributes and skills of the local player. Hidden attributes and skills are listed
-- too. Call `rebuild` afterwards.
-- @param target [Player player the data belongs to]
-- @param attributes [Map attribute data keyed by attribute ID, as `Player:get_attributes`
--   returns it]
-- @param skills=nil [Map Number ranks keyed by skill ID, as `Player:get_skills` returns it]
function PANEL:set_snapshot(target, attributes, skills)
  self.target = target
  self.snapshot = istable(attributes) and attributes or {}
  self.skill_snapshot = istable(skills) and skills or {}
end

--- Returns the player whose attributes and skills the list shows.
-- @return [Player the player of the snapshot, otherwise the local player]
function PANEL:get_target()
  return self.snapshot and self.target or PLAYER
end

--- Returns the data the list shows for an attribute.
-- @param attribute_id [String]
-- @return [Map level and boosts; nil if there is no data]
function PANEL:get_data(attribute_id)
  if self.snapshot then
    return self.snapshot[attribute_id]
  end

  return PLAYER:get_attribute_data(attribute_id)
end

--- Returns the rank the list shows for a skill.
-- @param skill_id [String]
-- @return [Number rank, 0 if there is none]
function PANEL:get_rank(skill_id)
  if self.snapshot then
    return tonumber(self.skill_snapshot[skill_id]) or 0
  end

  return PLAYER:get_skill(skill_id)
end

--- Collects the attributes and skills to list, grouped into sections. The sections of the
-- attributes come first, one for every category, sorted by name; then the sections of the
-- skills, one for every key stat, in the alphabetical order of the stat names; skills whose
-- key stat is not registered come last, under a section of their own. The entries of a
-- section are sorted by name.
-- @return [List<Map> sections: name (String header text), attributes (List<AttributeBase>)
--   and skills (List<SkillBase>)]
function PANEL:get_sections()
  local target = self:get_target()
  local attribute_sections = {}
  local skill_sections = {}
  local by_category = {}
  local by_stat = {}
  local translated_names = {}
  local other_skills

  for _, attribute_table in pairs(Attributes.get_stored()) do
    if self.snapshot or Attributes.is_visible(attribute_table, target) then
      local category = attribute_table.category or default_category
      local section = by_category[category]

      if !section then
        local name = translate('ui.attributes.attributes')

        if category != default_category then
          name ..= ' - '..translate(category)
        end

        section = { name = name, attributes = {}, skills = {} }
        by_category[category] = section

        attribute_sections[#attribute_sections + 1] = section
      end

      section.attributes[#section.attributes + 1] = attribute_table
      translated_names[attribute_table] = translate(attribute_table.name)
    end
  end

  for _, skill_table in pairs(Skills.get_stored()) do
    if self.snapshot or Skills.is_visible(skill_table, target) then
      local key_stat = isstring(skill_table.attribute) and Attributes.find(skill_table.attribute)
      local section

      if key_stat then
        section = by_stat[skill_table.attribute]

        if !section then
          local stat_name = translate(key_stat.name)

          section = {
            name = translate('ui.attributes.skills')..' - '..stat_name,
            stat_name = stat_name,
            stat_id = skill_table.attribute,
            attributes = {},
            skills = {}
          }
          by_stat[skill_table.attribute] = section

          skill_sections[#skill_sections + 1] = section
        end
      else
        other_skills = other_skills or { name = translate('ui.attributes.skills'), attributes = {}, skills = {} }
        section = other_skills
      end

      section.skills[#section.skills + 1] = skill_table
      translated_names[skill_table] = translate(skill_table.name)
    end
  end

  table.sort(attribute_sections, |a, b| -> a.name < b.name)

  table.sort(skill_sections, function(a, b)
    if a.stat_name != b.stat_name then
      return a.stat_name < b.stat_name
    end

    return a.stat_id < b.stat_id
  end)

  local sections = attribute_sections

  for _, section in ipairs(skill_sections) do
    sections[#sections + 1] = section
  end

  if other_skills then
    sections[#sections + 1] = other_skills
  end

  for _, section in ipairs(sections) do
    sort_definitions(section.attributes, translated_names)
    sort_definitions(section.skills, translated_names)
  end

  return sections
end

--- Returns the listed attributes and skills as one string, which changes whenever an
-- attribute or a skill appears in the list, disappears from it or moves, or the row of an
-- attribute gains or loses its line of details.
-- @param sections [List<Map> sections returned by get_sections]
-- @return [String]
function PANEL:get_listed(sections)
  local ids = {}

  for _, section in ipairs(sections) do
    ids[#ids + 1] = section.name

    for _, attribute_table in ipairs(section.attributes) do
      local detailed = has_details(self:get_data(attribute_table.attribute_id))

      ids[#ids + 1] = tostring(attribute_table.attribute_id)..(detailed ? '+' : '')
    end

    for _, skill_table in ipairs(section.skills) do
      ids[#ids + 1] = 'skill:'..tostring(skill_table.skill_id)
    end
  end

  return table.concat(ids, ';')
end

--- Recreates the list: a header for every section followed by the rows of its attributes
-- and skills, or a notice if there is nothing to show.
function PANEL:rebuild()
  local sections = self:get_sections()
  local text_color = get_color('text')
  local margin = math_scale(4)

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

  for index, section in ipairs(sections) do
    local header = self.scroll_panel:Add('DLabel')
    header:SetText(section.name)
    header:SetFont(Theme.get_font('menu_normal'))
    header:SetTextColor(get_color('text_muted'))
    header:SizeToContents()
    header:Dock(TOP)
    header:DockMargin(margin, index == 1 ? 0 : margin * 4, 0, margin)

    for _, attribute_table in ipairs(section.attributes) do
      local row = self.scroll_panel:Add('fl_attribute_row')
      row:Dock(TOP)
      row:DockMargin(0, 0, 0, margin)
      row:set_attribute(attribute_table)
      row:set_data(self:get_data(attribute_table.attribute_id))
      row:SetTall(row:get_row_height())

      self.rows[#self.rows + 1] = row
    end

    for _, skill_table in ipairs(section.skills) do
      local row = self.scroll_panel:Add('fl_attribute_row')
      row:Dock(TOP)
      row:DockMargin(0, 0, 0, margin)
      row:set_skill(skill_table)
      row:set_rank(self:get_rank(skill_table.skill_id))
      row:SetTall(row:get_row_height())

      self.rows[#self.rows + 1] = row
    end
  end
end

--- Brings the list up to date with the data it shows: rebuilds it if the set of listed
-- attributes and skills has changed, otherwise passes every attribute row its current data
-- and every skill row its current rank.
function PANEL:update()
  if self:get_listed(self:get_sections()) != self.listed then
    self:rebuild()

    return
  end

  for _, row in ipairs(self.rows) do
    if IsValid(row) then
      local skill_table = row:get_skill()

      if skill_table then
        row:set_rank(self:get_rank(skill_table.skill_id))
      else
        row:set_data(self:get_data(row:get_attribute().attribute_id))
      end
    end
  end
end

vgui.Register('fl_attributes', PANEL, 'fl_base_panel')

--- The line of one attribute or skill in the attribute list (`fl_attribute_row`).
-- The line of an attribute shows its icon and name, its level with boosts counted (as the
-- name of the level if the attribute names its levels), a bar that shows where the level
-- lies between the attribute's min and max with the boosted part in another color, and a
-- line that lists the boosts with the time each has left. The description of the attribute,
-- of its current level and its effects are the tooltip of the row.
-- The line of a skill shows its icon and name, its rank (as the name of the rank if the
-- skill names its ranks) and a bar that shows where the rank lies between 0 and the skill's
-- highest rank. The description of the skill and of its current rank are the tooltip of the
-- row.
-- Assign an attribute with `set_attribute` and its data with `set_data`, or a skill with
-- `set_skill` and its rank with `set_rank`. Derives from `fl_base_panel`.
local PANEL = {}
PANEL.attribute_table = false
PANEL.skill_table = false
PANEL.data = false
PANEL.rank = 0
PANEL.detailed = false
PANEL.name_text = ''
PANEL.value_text = ''
PANEL.boost_text = ''
PANEL.details_text = ''
PANEL.boost = 0
PANEL.level_fraction = 0
PANEL.boosted_fraction = 0

--- Picks the color of the line of details, the muted text color of the theme.
function PANEL:Init()
  self.details_color = get_color('text_muted')
end

--- Places the image of the icon in the top left corner of the row.
-- @param _w [Number panel width]
-- @param _h [Number panel height]
function PANEL:PerformLayout(_w, _h)
  if IsValid(self.image) then
    local padding, size = math_scale(8), math_scale(40)

    self.image:SetPos(padding, padding)
    self.image:SetSize(size, size)
  end
end

--- Draws the row: its background, a FontAwesome icon if the attribute or the skill has one,
-- the name and the level or rank, the bar and the line of details. The active theme's
-- PaintAttributeRow method replaces all of it by returning a value.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  if Theme.hook('PaintAttributeRow', self, w, h) != nil then return end

  draw.RoundedBox(Theme.get_option('corner_radius_small'), 0, 0, w, h, get_color('surface_raised'))

  if !self.attribute_table and !self.skill_table then return end

  local padding = math_scale(8)
  local icon_size = math_scale(40)
  local text_y = math_scale(6)
  local text_color = get_color('text')
  local background_color = get_color('surface_sunken')
  local boost_color = get_color('attribute_boost', default_boost_color)
  local hindrance_color = get_color('attribute_hindrance', default_hindrance_color)
  local font = Theme.get_font('text_normal')
  local x, right = padding, w - padding

  if self.fa_icon then
    local icon_center = padding + icon_size * 0.5

    FontAwesome:draw(
      self.fa_icon,
      icon_center,
      icon_center,
      math_scale(28),
      text_color,
      TEXT_ALIGN_CENTER,
      TEXT_ALIGN_CENTER
    )
  end

  if self.fa_icon or IsValid(self.image) then
    x = padding * 2 + icon_size
  end

  draw_simple_text(self.name_text, font, x, text_y, text_color)

  if self.boost_text != '' then
    local boost_w = draw_simple_text(
      self.boost_text,
      font,
      right,
      text_y,
      self.boost > 0 and boost_color or hindrance_color,
      TEXT_ALIGN_RIGHT
    )

    right = right - (boost_w or 0) - padding
  end

  draw_simple_text(self.value_text, font, right, text_y, text_color, TEXT_ALIGN_RIGHT)

  local bar_w, bar_y, bar_h = w - padding - x, math_scale(36), math_scale(8)
  local base_w = math_floor(bar_w * self.level_fraction)
  local boosted_w = math_floor(bar_w * self.boosted_fraction)
  local bar_radius = math_floor(bar_h * 0.5)

  draw.RoundedBox(bar_radius, x, bar_y, bar_w, bar_h, background_color)
  draw.RoundedBox(
    bar_radius,
    x,
    bar_y,
    math.min(base_w, boosted_w),
    bar_h,
    get_color('attribute_level', get_color('accent'))
  )

  if boosted_w > base_w then
    draw_box(x + base_w, bar_y, boosted_w - base_w, bar_h, boost_color)
  elseif boosted_w < base_w then
    draw_box(x + boosted_w, bar_y, base_w - boosted_w, bar_h, hindrance_color)
  end

  if self.details_text != '' then
    draw_simple_text(self.details_text, Theme.get_font('text_smaller'), x, math_scale(56), self.details_color)
  end
end

--- Creates the icon of the row. An icon that starts with 'fa-' is drawn as a FontAwesome
-- icon, any other is loaded as an image.
-- @param icon=nil [String FontAwesome icon name or path of an image]
function PANEL:set_icon(icon)
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
end

--- Sets the attribute this row shows and creates its icon.
-- @param attribute_table [AttributeBase attribute definition]
function PANEL:set_attribute(attribute_table)
  self.attribute_table = attribute_table
  self.skill_table = false
  self.tooltip_level = nil

  self:set_icon(attribute_table.icon)
  self:update()
end

--- Sets the skill this row shows and creates its icon.
-- @param skill_table [SkillBase skill definition]
function PANEL:set_skill(skill_table)
  self.skill_table = skill_table
  self.attribute_table = false
  self.tooltip_level = nil

  self:set_icon(skill_table.icon)
  self:update()
end

--- Returns the attribute this row shows.
-- @return [AttributeBase the attribute definition, or false if the row shows none]
function PANEL:get_attribute()
  return self.attribute_table
end

--- Returns the skill this row shows.
-- @return [SkillBase the skill definition, or false if the row shows none]
function PANEL:get_skill()
  return self.skill_table
end

--- Sets the data of the attribute and brings the row up to date with it.
-- @param data [Map level and boosts of the attribute; nil or false shows the attribute at
--   its default level]
function PANEL:set_data(data)
  self.data = data or false

  self:update()
end

--- Sets the rank of the skill and brings the row up to date with it.
-- @param rank [Number rank of the skill; anything else shows rank 0]
function PANEL:set_rank(rank)
  self.rank = tonumber(rank) or 0

  self:update()
end

--- Returns the height the row needs: taller if it has a line of details.
-- @return [Number]
function PANEL:get_row_height()
  return math_scale(self.detailed ? 82 : 58)
end

--- Builds the tooltip of the row: the description of the attribute or the skill, the
-- description of the given level or rank if there is one, and the effects an attribute
-- lists.
-- @param level [Number level the tooltip is for, boosts counted, or rank of a skill]
-- @return [String]
function PANEL:build_tooltip(level)
  local skill_table = self.skill_table
  local attribute_table = self.attribute_table
  local definition = skill_table or attribute_table
  local wrap_font, wrap_width = 'DermaDefault', DermaScale.scale(420)
  local lines = {}

  table.Add(lines, util.wrap_text(translate(definition.description), wrap_font, wrap_width) or {})

  local level_description

  if skill_table then
    level_description = skill_table:get_rank_description(level)
  else
    level_description = attribute_table:get_level_description(level)
  end

  if level_description then
    table.insert(lines, '')
    table.Add(lines, util.wrap_text(translate(level_description), wrap_font, wrap_width) or {})
  end

  if attribute_table and istable(attribute_table.effects) then
    local effect_lines = {}

    for _, effect in ipairs(attribute_table.effects) do
      if isstring(effect.text) and isfunction(effect.get_value) then
        table.insert(effect_lines, translate(effect.text)..' '..translate(tostring(effect.get_value(level))))
      end
    end

    if #effect_lines > 0 then
      table.insert(lines, '')
      table.Add(lines, effect_lines)
    end
  end

  return table.concat(lines, '\n')
end

--- Recalculates what the row shows from its skill and rank or from its attribute and data.
-- Does nothing if neither is set.
function PANEL:update()
  if self.skill_table then
    self:update_skill()
  elseif self.attribute_table then
    self:update_attribute()
  end
end

--- Recalculates what the row of a skill shows from its rank: the texts, the fraction of the
-- bar and, when the rank has changed, the tooltip.
function PANEL:update_skill()
  local skill_table = self.skill_table
  local max = skill_table.max
  local rank = self.rank
  local rank_name = skill_table:get_rank_name(rank)
  local fraction = max > 0 and math_clamp(rank / max, 0, 1) or 1

  self.boost = 0
  self.detailed = false
  self.name_text = translate(skill_table.name)

  if skill_table.hidden then
    self.name_text ..= ' '..translate('ui.attributes.hidden')
  end

  if rank_name then
    self.value_text = translate('ui.attributes.level_named', {
      name = translate(rank_name),
      level = format_number(rank)
    })
  else
    self.value_text = translate('ui.attributes.level', {
      level = format_number(rank),
      max = format_number(max)
    })
  end

  self.boost_text = ''
  self.level_fraction = fraction
  self.boosted_fraction = fraction
  self.details_text = ''

  if self.tooltip_level != rank then
    self.tooltip_level = rank

    self:SetTooltip(self:build_tooltip(rank))
  end
end

--- Recalculates what the row of an attribute shows from its data: the texts, the fractions
-- of the bars and, when the level has changed, the tooltip.
function PANEL:update_attribute()
  local attribute_table = self.attribute_table
  local data = self.data or {}
  local min, max = attribute_table.min, attribute_table.max
  local base_level = tonumber(data.level) or attribute_table.default
  local boosts = active_boosts(data.boosts)
  local boost = 0

  if attribute_table.boostable != false then
    boost = Attributes.sum_boosts(attribute_table, { level = base_level, boosts = boosts })
  end

  local level = base_level + boost
  local level_name = attribute_table:get_level_name(level)
  local range = max - min

  self.boost = boost
  self.detailed = has_details(data)
  self.name_text = translate(attribute_table.name)

  if attribute_table.hidden then
    self.name_text ..= ' '..translate('ui.attributes.hidden')
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
  self.level_fraction = range > 0 and math_clamp((base_level - min) / range, 0, 1) or 1
  self.boosted_fraction = range > 0 and math_clamp((level - min) / range, 0, 1) or 1
  self.details_text = ''

  if #boosts > 0 then
    self.details_text = translate('ui.attributes.boosts', {
      list = describe_boosts(boosts)
    })
  end

  if self.tooltip_level != level then
    self.tooltip_level = level

    self:SetTooltip(self:build_tooltip(level))
  end
end

vgui.Register('fl_attribute_row', PANEL, 'fl_base_panel')
