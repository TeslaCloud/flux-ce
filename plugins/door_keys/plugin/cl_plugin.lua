--- Client side of the Door Keys plugin: the menu in which the local player picks a key to add
-- to a door.

--- Lets the local player pick one of their keys to add to a door.
-- @param entity [Entity the door]
function DoorKeys:select_key(entity)
  local keys = PLAYER:find_items('key')

  local selector = vgui.Create('fl_selector')
  selector:set_title(t'ui.key.add.title')
  selector:set_text(t'ui.key.add.message')
  selector:set_value(t'ui.key.add.select')

  if keys then
    for _, key_item in pairs(keys) do
      selector:add_choice('['..key_item.instance_id..'] '..t(key_item:get_name()), function()
        Cable.send('fl_key_add', key_item.instance_id, entity)
      end)
    end
  end
end
