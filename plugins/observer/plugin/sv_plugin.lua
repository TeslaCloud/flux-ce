--- Server side of the Observer plugin: puts players into observer mode and takes them out of
-- it again.

--- Puts the player into observer mode: noclipping, invisible, not solid, invulnerable and
-- hidden from players without the 'moderate' permission. The previous position, angles and
-- move type are kept in actor.observer_data, the visible color by `Player:hide_body`.
-- @param actor [Player]
function Observer:start_observing(actor)
  actor.observer_data = {
    position = actor:GetPos(),
    angles = actor:EyeAngles(),
    move_type = actor:GetMoveType(),
    --- Called on the server when a player enters observer mode, to decide whether they
    -- are put back where they entered it once they leave.
    -- @param actor [Player The player entering observer mode]
    -- @return [Boolean Return false to leave the player where they stop observing]
    should_reset = (Plugin.call('ShouldObserverReset', actor) != false)
  }

  actor:SetMoveType(MOVETYPE_NOCLIP)
  actor:hide_body()
  actor:GodEnable()

  actor:set_nv('observer', true)
  actor:update_visibility()
end

--- Takes the player out of observer mode and restores what was saved on entering it.
-- The player is moved back to where they started unless ShouldObserverReset said not to or
-- should_reset is false. A vanished player stays hidden.
-- @param actor [Player]
-- @param should_reset=nil [Boolean false to leave the player where they are; nil to go by
--   what ShouldObserverReset decided on entering]
function Observer:stop_observing(actor, should_reset)
  local data = actor.observer_data

  if data then
    actor:SetMoveType(data.move_type or MOVETYPE_WALK)
    actor:show_body()
    actor:GodDisable()

    if should_reset != false and data.should_reset then
      timer.Simple(FrameTime(), function()
        if IsValid(actor) then
          actor:SetPos(data.position)
          actor:SetEyeAngles(data.angles)
        end
      end)
    end
  end

  actor.observer_data = nil
  actor:set_nv('observer', false)
  actor:hide_vanished_body()
  actor:update_visibility()
end
