--- Entity extensions of the admin plugin: hiding an entity from chosen players by stopping
-- its transmission to them, which the Vanish command is built on.

local ent_meta = FindMetaTable 'Entity'

--- Stops or resumes networking this entity and all of its children to a player. Does nothing
-- if the target is invalid.
-- @param target [Player the player to hide the entity from]
-- @param should_prevent [Boolean true to stop transmitting, false to resume]
function ent_meta:prevent_transmit(target, should_prevent)
  if IsValid(target) then
    self:SetPreventTransmit(target, should_prevent)

    for k, child in ipairs(self:GetChildren()) do
      if IsValid(child) then
        child:prevent_transmit(target, should_prevent)
      end
    end
  end
end

--- Stops or resumes networking this entity to every other player the condition does not
-- exclude. Also sets the entity's 'transmission_prevented' net var, sent only to itself.
-- ```
-- -- Hide the player from everyone except moderators.
-- target:prevent_transmit_conditional(true, function(ply)
--   if ply:can('moderator') then
--     return false
--   end
-- end)
-- ```
-- @param should_prevent [Boolean true to stop transmitting, false to resume]
-- @param condition=nil [Function called as condition(receiver, entity, should_prevent); return
--   false to leave that player unaffected]
function ent_meta:prevent_transmit_conditional(should_prevent, condition)
  condition = condition or function() return true end

  for k, v in player.Iterator() do
    if v != self and condition(v, self, should_prevent) != false then
      self:prevent_transmit(v, should_prevent)
    end
  end

  -- Let the entity itself know it's gone.
  self:set_nv('transmission_prevented', should_prevent, self)
end
