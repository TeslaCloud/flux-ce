--- Client side of the core of the Bolt library: the `can` global, which asks about the local
-- player.

--- Checks whether the local player may perform an action. Client-side variant.
-- @param action [String permission ID]
-- @param object=nil [String object name the permission was allowed for]
-- @return [Boolean]
function can(action, object)
  return PLAYER:can(action, object)
end
