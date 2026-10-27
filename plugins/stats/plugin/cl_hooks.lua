--- Client side of the Stats plugin: adds the stats stage to character creation, words the
-- refusal of a character whose stat levels the server did not accept, adds the character
-- sheet to the tab menu as its first and default page, asks the server for the rolls of the
-- sheet and keeps their results for its roll buttons, and opens the window that shows a
-- member of staff the attributes and skills of another player's character when the server
-- sends them, which the `attribute list` command makes it do.

Stats.rolls = Stats.rolls or {}

--- How long a roll button tumbles at least before it shows the result, in seconds, so that
-- the result of a quick answer does not just blink into place.
Stats.roll_tumble_time = 0.45

--- How long a roll button waits for the answer of the server before it gives up, in seconds.
Stats.roll_timeout = 3

--- Asks the server to roll a stat or a skill of the local player and starts the animation
-- of its roll button. Does nothing sooner than `Stats.roll_interval` after the last roll,
-- which the server would refuse.
-- @param id [String ID of the stat or the skill]
-- @return [Boolean whether the roll was asked for]
function Stats:request_roll(id)
  local now = RealTime()

  if self.next_roll and self.next_roll > now then
    return false
  end

  self.next_roll = now + self.roll_interval + 0.1
  self.rolls[id] = { started = now, pending = true }

  Cable.send('fl_stats_roll', id)

  return true
end

--- Returns the last roll of a stat or a skill that the local player made from the
-- character sheet.
-- @param id [String ID of the stat or the skill]
-- @return [Map started (Number RealTime of the click), pending (Boolean while the server has
--   not answered), result (Map formula, total, natural, critical and rolls, once it has),
--   landed (Number RealTime at which the button stops tumbling and shows the result) and text
--   (String the result in words); nil if there is none]
function Stats:get_roll(id)
  return self.rolls[id]
end

--- Opens a window that lists the given attributes and skills of a player's character,
-- hidden ones included. The list is a snapshot: it does not follow later changes. A window
-- that is still open from an earlier call is replaced.
-- @param target [Player player the attributes and skills belong to]
-- @param attributes [Map attribute data keyed by attribute ID, as `Player:get_attributes`
--   returns it]
-- @param skills=nil [Map Number ranks keyed by skill ID, as `Player:get_skills` returns it]
-- @return [Panel the `fl_frame` that was opened]
function Attributes.open_viewer(target, attributes, skills)
  if IsValid(Attributes.viewer) then
    Attributes.viewer:safe_remove()
  end

  local name = IsValid(target) and target:name() or ''
  local title = t('ui.attributes.viewer_title', { name = name })

  local frame = vgui.Create('fl_frame')
  frame:SetSize(math.scale(720), math.scale(640))
  frame:Center()
  frame:MakePopup()
  frame:set_title(title)
  frame:set_draggable(true)

  local attribute_list = vgui.Create('fl_attributes', frame)
  attribute_list:Dock(FILL)
  attribute_list:set_snapshot(target, attributes, skills)
  attribute_list:rebuild()

  frame.attribute_list = attribute_list

  Attributes.viewer = frame

  return frame
end

--- Registers the stats character creation panel and the character sheet with the theme.
-- @param current_theme [Theme theme that was loaded]
function Stats:OnThemeLoaded(current_theme)
  current_theme:add_panel('ui.char_create.stats', function(_id, parent, ...)
    return vgui.Create('fl_character_creation_stats', parent)
  end)

  current_theme:add_panel('character_sheet', function(_id, parent, ...)
    return vgui.Create('fl_character_sheet', parent)
  end)
end

--- Adds the character sheet to the tab menu as its first and default page while the local
-- player has a character. Without one the sheet is also forgotten as the page to reopen,
-- since the tab menu expects the page it reopens to exist.
-- @param menu [Panel the tab menu]
function Stats:AddTabMenuItems(menu)
  if !PLAYER:is_character_loaded() then
    if PLAYER.tab_panel == 'character_sheet' then
      PLAYER.tab_panel = nil
    end

    return
  end

  menu:add_menu_item('character_sheet', {
    title = t'ui.tab_menu.character_sheet',
    panel = 'fl_character_sheet',
    icon = 'fa-id-card',
    priority = 5,
    default = true
  })
end

--- Adds the stats stage to character creation.
-- @param panel [Panel character creation menu]
function Stats:AddCharacterCreationMenuStages(panel)
  panel:add_stage('ui.char_create.stats')
end

--- Returns the error text for characters whose attribute points do not add up.
-- @param _success [Boolean whether the character was created]
-- @param status [Number CHAR_ERR_ status code]
-- @return [String error text, nil for other statuses]
function Stats:GetCharCreationErrorText(_success, status)
  if status == CHAR_ERR_ATTRIBUTE_SUM then
    return t'error.attribute.sum'
  end
end

Cable.receive('fl_stats_roll_result', function(id, result)
  if !isstring(id) then return end

  if !istable(result) or !isnumber(result.total) then
    Stats.rolls[id] = nil

    return
  end

  local now = RealTime()
  local roll = Stats.rolls[id] or { started = now }
  local definition = Attributes.find(id) or Skills.find(id)

  roll.pending = false
  roll.result = result
  roll.landed = math.max(now, roll.started + Stats.roll_tumble_time)
  roll.text = t('ui.character_sheet.roll_result', {
    name = definition and t(definition.name) or id,
    roll = Stats:format_roll(result)
  })

  Stats.rolls[id] = roll

  --- Called on the client when the server has answered a roll that the local player made
  -- from the character sheet, after the result has been stored for `Stats:get_roll`.
  -- @param id [String ID of the stat or the skill]
  -- @param result [Map formula, total, natural, critical and rolls of the `Dice` result]
  hook.Run('OnStatRollResult', id, result)
end)

Cable.receive('fl_attributes_view', function(target, attributes, skills)
  if !istable(attributes) then return end

  Attributes.open_viewer(target, attributes, skills)
end)
