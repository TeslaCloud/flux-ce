--- The character sheet of the tab menu (`fl_character_sheet`): the 'character_sheet' Lumen
-- template mounted into the panel, which shows the character of the local player with its
-- level, health, stats and skills and lets the player roll them and spend unspent points.
-- What the sheet shows arrives from the server over time, so twice a second the panel checks
-- whether any of it has changed and renders the template again if it has. `rebuild` renders
-- it again right away. Derives from `fl_base_panel`.

local math_min = math.min
local math_scale = math.scale
local tostring = tostring
local table_concat = table.concat

local PANEL = {}
PANEL.update_interval = 0.5

--- Builds a string out of everything the sheet shows that the server can change: the name
-- and the faction of the character, its level, experience, health and unspent points, the
-- config the proficiency depends on, the level and visibility of every attribute and the
-- rank and visibility of every skill. The string differs whenever the sheet would look
-- different.
-- @return [String]
local function get_state_key()
  local actor = PLAYER

  if !IsValid(actor) or !actor:is_character_loaded() then
    return ''
  end

  local parts = {
    actor:name(),
    actor:Health(),
    actor:GetMaxHealth(),
    tostring(Config.get('stats_rank_bonus'))
  }

  if Factions and isfunction(actor.get_faction_id) then
    parts[#parts + 1] = tostring(actor:get_faction_id())
  end

  if Levels and isfunction(actor.get_level) then
    parts[#parts + 1] = actor:get_level()
    parts[#parts + 1] = actor:get_experience()
    parts[#parts + 1] = actor:get_skill_points()
    parts[#parts + 1] = actor:get_attribute_points()
  end

  for id, attribute_table in SortedPairs(Attributes.get_stored()) do
    if Attributes.is_visible(attribute_table, actor) then
      parts[#parts + 1] = id..'='..tostring(actor:get_attribute(id))..'/'..tostring(actor:get_attribute(id, true))
    end
  end

  for id, skill in SortedPairs(Skills.get_stored()) do
    if Skills.is_visible(skill, actor) then
      parts[#parts + 1] = 'skill:'..id..'='..tostring(actor:get_skill(id))
    end
  end

  return table_concat(parts, ';')
end

--- Mounts the character sheet template.
function PANEL:Init()
  self.state_key = get_state_key()
  self.root = Lumen.render('character_sheet', nil, self)
end

--- Renders the character sheet template again with the current data of the local player.
function PANEL:rebuild()
  self.state_key = get_state_key()

  if self.root then
    self.root:update()
  else
    self.root = Lumen.render('character_sheet', nil, self)
  end
end

--- Renders the sheet again when what it shows has changed, checking at most twice a second.
function PANEL:Think()
  self.BaseClass.Think(self)

  local cur_time = CurTime()

  if self.next_update and self.next_update > cur_time then return end

  self.next_update = cur_time + self.update_interval

  if get_state_key() != self.state_key then
    self:rebuild()
  end
end

--- Takes the template down with the panel.
function PANEL:OnRemove()
  if self.root then
    self.root:unmount()
    self.root = nil
  end
end

--- Returns the size the tab menu gives this panel when it opens it: 1400 by 900 at 1080p,
-- kept within the screen below the button bar of the menu.
-- @return [Number width, Number height]
function PANEL:get_menu_size()
  return math_min(math_scale(1400), ScrW() - math_scale(32)), math_min(math_scale(900), ScrH() - math_scale(96))
end

vgui.Register('fl_character_sheet', PANEL, 'fl_base_panel')
