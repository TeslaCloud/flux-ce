--- Client side of the Attributes plugin: the Attributes entry of the tab menu, and the window
-- that shows a member of staff the attributes of another player's character when the
-- server sends them, which the CharAttributes command makes it do.

--- Opens a window that lists the given attributes of a player's character, hidden
-- attributes included. The list is a snapshot: it does not follow later changes. A window
-- that is still open from an earlier call is replaced.
-- @param target [Player player the attributes belong to]
-- @param attributes [Map attribute data keyed by attribute ID, as `Player:get_attributes`
--   returns it]
-- @return [Panel the `fl_frame` that was opened]
function Attributes.open_viewer(target, attributes)
  if IsValid(Attributes.viewer) then
    Attributes.viewer:safe_remove()
  end

  local name = IsValid(target) and target:name() or ''
  local escaped_name = name:gsub('%%', '%%%%')
  local title = t('ui.attributes.viewer_title', { name = escaped_name })

  local frame = vgui.Create('fl_frame')
  frame:SetSize(math.scale(720), math.scale(640))
  frame:Center()
  frame:MakePopup()
  frame:set_title(title)
  frame:set_draggable(true)

  local attribute_list = vgui.Create('fl_attributes', frame)
  attribute_list:Dock(FILL)
  attribute_list:set_snapshot(target, attributes)
  attribute_list:rebuild()

  frame.attribute_list = attribute_list

  Attributes.viewer = frame

  return frame
end

--- Adds the Attributes entry to the tab menu when at least one attribute is visible to the
-- local player. When none is, the tab is also forgotten as the one to reopen, since the tab
-- menu expects the tab it reopens to exist.
-- @param menu [Panel the tab menu]
function AttributesPlugin:AddTabMenuItems(menu)
  local visible = false

  for k, v in pairs(Attributes.get_stored()) do
    if Attributes.is_visible(v, PLAYER) then
      visible = true

      break
    end
  end

  if !visible then
    if PLAYER.tab_panel == 'attributes' then
      PLAYER.tab_panel = nil
    end

    return
  end

  menu:add_menu_item('attributes', {
    title = t'ui.tab_menu.attributes',
    panel = 'fl_attributes',
    icon = 'fa-chart-bar',
    priority = 35
  })
end

Cable.receive('fl_attributes_view', function(target, attributes)
  if !istable(attributes) then return end

  Attributes.open_viewer(target, attributes)
end)
