--- Server side of the core of the Bolt library: the `can` global, which asks about the
-- player held in the `current_player` global.

local IsValid = IsValid

--- Checks whether the player held in the current_player global may perform an action.
-- Server-side variant; returns false when that global is not a valid player.
-- @param action [String permission ID]
-- @param object=nil [String object name the permission was allowed for]
-- @return [Boolean]
function can(action, object)
  if IsValid(current_player) then
    return current_player:can(action, object)
  end

  return false
end
