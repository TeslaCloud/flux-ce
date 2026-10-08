--- Server side of the Observer plugin: puts players into observer mode when they noclip and
-- restores them when they leave it.

--- Puts the player into observer mode: noclipping, invisible, not solid, invulnerable and
-- hidden from players without the 'moderator' permission. The previous position, angles,
-- color and move type are kept in actor.observer_data. Requires the 'noclip' permission.
-- @param actor [Player]
-- @return [Boolean always false, which blocks the default noclip]
function Observer:PlayerEnterNoclip(actor)
  if !actor:can('noclip') then
    actor:notify('You do not have permission to do this.')

    return false
  end

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
  actor:SetColor(Color(0, 0, 0, 0))
  actor:GodEnable()

  actor:set_nv('observer', true)

  -- Respect that one vanish command from the admin mod.
  if !actor.is_vanished then
    actor:prevent_transmit_conditional(true, function(ply)
      if ply:can('moderator') then
        return false
      end
    end)
  end

  return false
end

--- Takes the player out of observer mode and restores what was saved on entering it.
-- The player is moved back to where they started unless ShouldObserverReset said not to.
-- @param actor [Player]
-- @return [Boolean always false, which blocks the default noclip]
function Observer:PlayerExitNoclip(actor)
  local data = actor.observer_data

  if data then
    actor:SetMoveType(data.move_type or MOVETYPE_WALK)

    -- The engine drops the carried object as soon as the weapon is drawn again, and
    -- draws the weapon by itself once the object is let go of.
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

  if !actor.is_vanished then
    actor:prevent_transmit_conditional(false, function(ply)
      if ply:can('moderator') then
        return false
      end
    end)
  end

  return false
end

--- Keeps players where they are when leaving observer mode if the 'observer_reset' config
-- is off.
-- @param actor [Player]
-- @return [Boolean false if the player should not be moved back, nil otherwise]
function Observer:ShouldObserverReset(actor)
  if !Config.get('observer_reset') then
    return false
  end
end
