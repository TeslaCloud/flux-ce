--- Client side of the Stats plugin: adds the stats stage to character creation, words the
-- refusal of a character whose stat levels the server did not accept, adds the character
-- sheet to the tab menu as its first and default page, and opens the window that shows a
-- member of staff the attributes and skills of another player's character when the server
-- sends them, which the `attribute list` command makes it do.

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
  current_theme:add_panel('ui.char_create.stats', function(id, parent, ...)
    return vgui.Create('fl_character_creation_stats', parent)
  end)

  current_theme:add_panel('character_sheet', function(id, parent, ...)
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
-- @param success [Boolean whether the character was created]
-- @param status [Number CHAR_ERR_ status code]
-- @return [String error text, nil for other statuses]
function Stats:GetCharCreationErrorText(success, status)
  if status == CHAR_ERR_ATTRIBUTE_SUM then
    return t'error.attribute.sum'
  end
end

Cable.receive('fl_attributes_view', function(target, attributes, skills)
  if !istable(attributes) then return end

  Attributes.open_viewer(target, attributes, skills)
end)
