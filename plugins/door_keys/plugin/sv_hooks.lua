--- Server-side hooks of the Door Keys plugin: they let the holders of a key lock its doors.

--- Lets players lock and unlock doors that one of their keys belongs to.
-- @param actor [Player player trying to lock the door]
-- @param entity [Entity door]
-- @return [Boolean true if the player has a key for the door, nil otherwise]
function DoorKeys:PlayerCanLockDoor(actor, entity)
  local keys = actor:find_items('key')

  if keys then
    local door_id = entity:MapCreationID()

    for _, key_item in pairs(keys) do
      if table.HasValue(key_item:get_data('doors', {}), door_id) then
        return true
      end
    end
  end
end
