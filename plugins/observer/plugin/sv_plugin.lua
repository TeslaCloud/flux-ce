--- Server side of the Observer plugin: puts players into observer mode and takes them out of
-- it again.

local invisible_color = Color(0, 0, 0, 0)

--- Puts the player into observer mode: noclipping, invisible, not solid, invulnerable and
-- hidden from players without the 'moderate' permission. The previous position, angles,
-- color and move type are kept in actor.observer_data.
-- @param actor [Player]
function Observer:start_observing(actor)
  actor.observer_data = {
    position = actor:GetPos(),
    angles = actor:EyeAngles(),
    color = actor:GetColor(),
    move_type = actor:GetMoveType(),
    --- Called on the server when a player enters observer mode, to decide whether they
    -- are put back where they entered it once they leave.
    -- @param actor [Player The player entering observer mode]
    -- @return [Boolean Return false to leave the player where they stop observing]
    should_reset = (Plugin.call('ShouldObserverReset', actor) != false)
  }

  actor:SetMoveType(MOVETYPE_NOCLIP)
  actor:DrawWorldModel(false)
  actor:DrawShadow(false)
  actor:SetNoDraw(true)
  actor:SetNotSolid(true)
  actor:SetColor(invisible_color)
  actor:GodEnable()

  actor:set_nv('observer', true)
  actor:update_visibility()
end

--- Takes the player out of observer mode and restores what was saved on entering it.
-- The player is moved back to where they started unless ShouldObserverReset said not to.
-- The weapon is only drawn again when the player carries nothing, since the engine drops
-- the carried object as soon as the weapon is drawn and draws the weapon by itself once
-- the object is let go of. A vanished player stays hidden.
-- @param actor [Player]
function Observer:stop_observing(actor)
  local data = actor.observer_data

  if data then
    actor:SetMoveType(data.move_type or MOVETYPE_WALK)

    if !IsValid(actor.holding_object) then
      actor:DrawWorldModel(true)
    end

    actor:DrawShadow(true)
    actor:SetNoDraw(false)
    actor:SetNotSolid(false)
    actor:SetColor(data.color)
    actor:GodDisable()

    if data.should_reset then
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
