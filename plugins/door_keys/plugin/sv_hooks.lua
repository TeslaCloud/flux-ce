--- Server-side hooks of the Door Keys plugin: they let the holders of a key lock its doors.

--- Lets players lock and unlock doors that one of their keys opens.
-- @param actor [Player player trying to lock the door]
-- @param entity [Entity door]
-- @return [Boolean true if the player has a key for the door, nil otherwise]
-- @see [DoorKeys#opens]
function DoorKeys:PlayerCanLockDoor(actor, entity)
  for _, key_item in ipairs(actor:find_items('key')) do
    if self:opens(key_item, entity) then
      return true
    end
  end
end
