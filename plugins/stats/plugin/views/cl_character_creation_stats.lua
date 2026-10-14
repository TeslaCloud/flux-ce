--- The stats stage of character creation (`fl_character_creation_stats`): a list of the
-- stats with a counter each, the points that are left to spend, a button that spreads the
-- points at random, and a panel that describes the selected stat, the level picked for it,
-- the bonus the chosen faction adds and what the stat changes in play at that level.
-- A stat can be raised up to its creation limit (`Stats:get_creation_max`), below the
-- highest level it can reach in play. The picked levels are handed over as the
-- `attributes` field of the creation data, which the server checks again.

local math_scale = math.scale
local math_scale_x = math.scale_x
local get_font = Theme.get_font
local panel_background = Color(0, 0, 0, 100)

local PANEL = {}
PANEL.id = 'stats'
PANEL.text = 'ui.char_create.stats'

--- Creates the icon of a stat: a FontAwesome icon if its name starts with 'fa-', otherwise
-- an image.
-- @param parent [Panel panel to put the icon in]
-- @param icon [String FontAwesome icon name or path of an image]
-- @param size [Number width and height of the icon]
-- @return [Panel the icon, or nil if the stat has none]
local function create_icon(parent, icon, size)
  if !isstring(icon) or icon == '' then return end

  if icon:start_with('fa-') then
    local icon_size = math.floor(size * 0.75)
    local panel = vgui.Create('DPanel', parent)
    panel:SetSize(size, size)
    panel:SetMouseInputEnabled(false)
    panel.Paint = function(pnl, w, h)
      FontAwesome:draw(icon, w * 0.5, h * 0.5, icon_size, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    return panel
  end

  local image = vgui.Create('DImage', parent)
  image:SetImage(icon)
  image:SetKeepAspect(true)
  image:SetSize(size, size)

  return image
end

--- Sets up the available attribute points.
function PANEL:Init()
  self.stats = {}
  self.bonuses = {}
  self.start_points = Stats:default_attribute_points()
  self.points = self.start_points

  self:DockPadding(0, math_scale(48), 0, 0)
end

--- Returns the bonus that the faction chosen earlier in character creation adds to a stat.
-- @param attribute_id [String ID of the stat]
-- @return [Number bonus levels, 0 if the faction gives none]
function PANEL:get_bonus(attribute_id)
  return self.bonuses[attribute_id] or 0
end

--- Draws the remaining attribute points in the bottom right corner.
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
function PANEL:PaintOver(w, h)
  local text = t'ui.char_create.stats_points'..self.points
  local font = get_font('text_normal_large')
  local text_w, text_h = util.text_size(text, font)
  surface.DisableClipping(true)
    draw.SimpleText(text, font, w - text_w, h - text_h, Theme.get_color('schema_text'))
  surface.DisableClipping(false)
end

--- Builds the list of stat attributes with point counters, the attribute details panel and the randomize button,
-- restoring previously entered values. The points that are left are worked out from the
-- restored levels, so that they always match what the server is going to check.
-- @param parent [Panel character creation menu]
function PANEL:on_open(parent)
  local scrw, scrh = ScrW(), ScrH()
  local fa_icon_size = math_scale(16)
  local faction_table = Factions and Factions.find_by_id(parent.char_data.faction)
  local selected_attribute

  self.bonuses = Stats:faction_bonuses_enabled() and Stats:get_faction_bonuses(faction_table) or {}

  self.attributes_list = vgui.Create('DScrollPanel', self)
  self.attributes_list:SetSize(scrw * 0.15 - math_scale_x(4))
  self.attributes_list:DockMargin(0, 0, 0, math_scale(48))
  self.attributes_list:Dock(LEFT)
  self.attributes_list:GetCanvas():DockPadding(math_scale_x(4), math_scale(4), math_scale_x(4), math_scale(4))
  self.attributes_list.Paint = function(pnl, w, h)
    draw.RoundedBox(0, 0, 0, w, h, panel_background)
  end

  self.attribute_panel = vgui.Create('DScrollPanel', self)
  self.attribute_panel:SetSize(scrw * 0.35 - math_scale_x(4))
  self.attribute_panel:DockMargin(0, 0, 0, math_scale(48))
  self.attribute_panel:Dock(RIGHT)
  self.attribute_panel:GetCanvas():DockPadding(math_scale_x(48), math_scale(32), math_scale_x(48), math_scale(32))
  self.attribute_panel.Paint = function(pnl, w, h)
    draw.RoundedBox(0, 0, 0, w, h, panel_background)
  end

  self.attribute_panel.rebuild = function(pnl)
    if !selected_attribute then return end

    chat.PlaySound()

    pnl:Clear()

    local panel = vgui.Create('DPanel', pnl)
    panel:SetDrawBackground(false)
    panel:Dock(TOP)

    local icon = create_icon(panel, selected_attribute.icon, math_scale(48))

    local title = vgui.Create('DLabel', panel)
    title:SetText(t(selected_attribute.name))
    title:SetFont(Font.size(get_font('text_bold'), math_scale(48)))
    title:SetColor(color_white)
    title:SetContentAlignment(9)
    title:SetPos(icon and icon:GetWide() + math_scale_x(16) or 0)
    title:SizeToContents()

    panel:SetTall(math.max(title:GetTall(), icon and icon:GetTall() or 0) + math_scale(16))

    local desc = vgui.Create('DLabel', pnl)
    desc:SetText(t(selected_attribute.description))
    desc:SetFont(get_font('text_normal'))
    desc:SetColor(color_white)
    desc:SetWrap(true)
    desc:SetMultiline(true)
    desc:SetAutoStretchVertical(true)
    desc:Dock(TOP)

    local raw_value = self.stats[selected_attribute.attribute_id].counter:get_value()

    panel = vgui.Create('DPanel', pnl)
    panel:SetDrawBackground(false)
    panel:Dock(TOP)

    local current_level = vgui.Create('DLabel', panel)
    current_level:SetText(t('ui.char_create.cur_level')..': ')
    current_level:SetFont(Font.size(get_font('text_bold'), math_scale(32)))
    current_level:SetColor(color_white)
    current_level:SetContentAlignment(1)
    current_level:SizeToContents()

    local level_name = vgui.Create('DLabel', panel)
    level_name:SetText(t(selected_attribute:get_level_name(raw_value) or ''))
    level_name:SetFont(get_font('text_normal_large'))
    level_name:SetColor(color_white)
    level_name:SetContentAlignment(2)
    level_name:SizeToContents()

    panel:SetTall(current_level:GetTall() + math_scale(32))
    current_level:SetPos(0, panel:GetTall() - current_level:GetTall() - math_scale(1))
    level_name:SetPos(current_level:GetWide(), panel:GetTall() - level_name:GetTall())

    local level_desc = vgui.Create('DLabel', pnl)
    level_desc:SetText(t(selected_attribute:get_level_description(raw_value) or ''))
    level_desc:SetFont(get_font('text_normal'))
    level_desc:SetColor(color_white)
    level_desc:SetWrap(true)
    level_desc:SetMultiline(true)
    level_desc:SetAutoStretchVertical(true)
    level_desc:Dock(TOP)

    local bonus = self:get_bonus(selected_attribute.attribute_id)

    if bonus != 0 then
      local bonus_label = vgui.Create('DLabel', pnl)
      bonus_label:SetText(t('ui.char_create.faction_bonus', { bonus = Stats:format_change(bonus) }))
      bonus_label:SetFont(get_font('text_normal'))
      bonus_label:SetColor(Stats:get_change_color(bonus))
      bonus_label:SizeToContents()
      bonus_label:DockMargin(0, math_scale(8), 0, 0)
      bonus_label:Dock(TOP)
    end

    local active_effects = {}

    for k, v in ipairs(selected_attribute.effects or {}) do
      if !isfunction(v.is_active) or v.is_active() then
        table.insert(active_effects, v)
      end
    end

    if #active_effects > 0 then
      local effect_level = raw_value + bonus
      local effect_title = vgui.Create('DLabel', pnl)
      effect_title:SetText(t('ui.char_create.effects'))
      effect_title:SetFont(Font.size(get_font('text_bold'), math_scale(32)))
      effect_title:SetColor(color_white)
      effect_title:SetContentAlignment(1)
      effect_title:SizeToContents()
      effect_title:Dock(TOP)
      effect_title:SetTall(effect_title:GetTall() + math_scale(32))

      for k, v in ipairs(active_effects) do
        local effect = vgui.Create('DLabel', pnl)
        effect:SetText(t(v.text)..' '..t(v.get_value(effect_level)))
        effect:SetFont(get_font('text_normal'))
        effect:SetColor(v.get_color(effect_level))
        effect:SizeToContents()
        effect:Dock(TOP)
      end
    end
  end

  for k, v in pairs(Attributes.get_stored()) do
    local stat_line = vgui.Create('DPanel', self.attributes_list)
    stat_line:SetTall(math_scale(64))
    stat_line:Dock(TOP)
    stat_line:DockMargin(0, 0, 0, math_scale(4))
    stat_line.attribute_table = v
    stat_line.Paint = function(pnl, w, h)
      if selected_attribute and selected_attribute.attribute_id == pnl.attribute_table.attribute_id then
        draw.box_outlined(0, 0, 0, w, h, 2, Theme.get_color('accent'), 0)
      end
    end

    stat_line.OnMousePressed = function(pnl)
      if selected_attribute != v then
        selected_attribute = v

        self.attribute_panel:rebuild()
      end
    end

    local counter = vgui.Create('fl_counter', stat_line)
    counter:Dock(RIGHT)
    counter:set_value(v.default)
    counter:set_min_max(v.min, Stats:get_creation_max(v))
    counter:set_font(get_font('main_menu_titles'))
    counter.on_click = function(btn, new_value, old_value)
      local diff = new_value - old_value

      if selected_attribute != v then
        selected_attribute = v
      end

      if diff > 0 and self.points - diff < 0 then
        return false
      else
        surface.PlaySound('buttons/blip1.wav')

        self.points = self.points - diff
      end
    end

    counter.post_click = function(pnl)
      self.attribute_panel:rebuild()
    end

    local icon_size = stat_line:GetTall() * 0.75
    local icon = create_icon(stat_line, v.icon, icon_size)

    if icon then
      icon:SetPos(math_scale_x(4), stat_line:GetTall() * 0.5 - icon_size * 0.5)
    end

    local title = vgui.Create('DLabel', stat_line)
    title:SetText(t(v.name))
    title:SetFont(get_font('main_menu_titles'))
    title:SetColor(color_white)
    title:SetPos(icon and icon:GetWide() + math_scale_x(24) or 0, stat_line:GetTall() * 0.5 - title:GetTall() * 0.5)
    title:SizeToContents()

    stat_line.counter = counter
    self.stats[k] = stat_line
  end

  self.random = vgui.Create('fl_button', self)
  self.random:SetSize(self.attributes_list:GetWide(), Theme.get_option('menu_sidebar_button_height'))
  self.random:SetPos(math_scale_x(8), scrh * 0.5 - self.random:GetTall())
  self.random:set_icon('fa-random')
  self.random:set_icon_size(fa_icon_size)
  self.random:SetFont(get_font('text_normal'))
  self.random:SetTitle(t'ui.char_create.stats_random')
  self.random:SetDrawBackground(false)
  self.random.DoClick = function(btn)
    local cur_time = CurTime()

    if !self.random.next_click or self.random.next_click <= cur_time then
      for k, v in pairs(self.stats) do
        local number = v.counter:get_value()

        if number > v.attribute_table.min then
          self.points = self.points + (number - v.attribute_table.min)
          v.counter:set_value(v.attribute_table.min)
        end
      end

      while self.points > 0 do
        local stat = table.Random(self.stats)
        local number = stat.counter:get_value()

        if number < Stats:get_creation_max(stat.attribute_table) then
          number = number + 1
          stat.counter:set_value(number)

          self.points = self.points - 1
        end
      end

      surface.PlaySound('buttons/button4.wav')
      self.attribute_panel:rebuild()
      self.random.next_click = cur_time + 1
    end
  end

  local saved_levels = parent.char_data.attributes
  local spent = 0

  if istable(saved_levels) then
    for k, v in pairs(self.stats) do
      local attribute_table = v.attribute_table
      local level = tonumber(saved_levels[k])

      if level then
        level = math.Clamp(math.floor(level), attribute_table.min, Stats:get_creation_max(attribute_table))

        v.counter:set_value(level)

        spent = spent + level - attribute_table.default
      end
    end
  end

  self.points = self.start_points - spent
end

--- Stores the chosen attribute values in the character data. The points that are left are
-- not stored: they follow from the values when the stage is opened again.
-- @param parent [Panel character creation menu]
function PANEL:on_close(parent)
  local stats_table = {}

  for k, v in pairs(self.stats) do
    stats_table[k] = v.counter:get_value()
  end

  parent:collect_data({
    attributes = stats_table
  })
end

--- Checks that all attribute points have been spent and none were overspent.
-- @return [Boolean false and String error text if the points are invalid, nil otherwise]
function PANEL:on_validate()
  local sum = 0

  for k, v in pairs(self.stats) do
    sum = sum + v.counter:get_value()
  end

  if self.points < 0 or sum > self.start_points then
    return false, t'ui.char_create.invalid_points'
  end

  if self.points > 0 then
    return false, t'ui.char_create.excess_points'
  end
end

vgui.Register('fl_character_creation_stats', PANEL, 'fl_character_creation_base')
