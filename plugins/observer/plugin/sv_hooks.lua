--- Puts the player into observer mode: noclipping, invisible, not solid, invulnerable and
-- hidden from players without the 'moderator' permission. The previous position, angles,
-- color and move type are kept in player.observer_data. Requires the 'noclip' permission.
-- @param player [Player]
-- @return [Boolean always false, which blocks the default noclip]
function Observer:PlayerEnterNoclip(player)
  if !player:can('noclip') then
    player:notify('You do not have permission to do this.')

    return false
  end

  player.observer_data = {
    position = player:GetPos(),
    angles = player:EyeAngles(),
    color = player:GetColor(),
    move_type = player:GetMoveType(),
    should_reset = (Plugin.call('ShouldObserverReset', player) != false)
  }

  player:SetMoveType(MOVETYPE_NOCLIP)
  player:DrawWorldModel(false)
  player:DrawShadow(false)
  player:SetNoDraw(true)
  player:SetNotSolid(true)
  player:SetColor(Color(0, 0, 0, 0))
  player:GodEnable()

  player:set_nv('observer', true)

  -- Respect that one vanish command from the admin mod.
  if !player.is_vanished then
    player:prevent_transmit_conditional(true, function(ply)
      if ply:can('moderator') then
        return false
      end
    end)
  end

  return false
end

--- Takes the player out of observer mode and restores what was saved on entering it.
-- The player is moved back to where they started unless ShouldObserverReset said not to.
-- @param player [Player]
-- @return [Boolean always false, which blocks the default noclip]
function Observer:PlayerExitNoclip(player)
  local data = player.observer_data

  if data then
    player:SetMoveType(data.move_type or MOVETYPE_WALK)
    player:DrawWorldModel(true)
    player:DrawShadow(true)
    player:SetNoDraw(false)
    player:SetNotSolid(false)
    player:SetColor(data.color)
    player:GodDisable()

    if data.should_reset then
      timer.Simple(FrameTime(), function()
        if IsValid(player) then
          player:SetPos(data.position)
          player:SetEyeAngles(data.angles)
        end
      end)
    end
  end

  player.observer_data = nil
  player:set_nv('observer', false)

  if !player.is_vanished then
    player:prevent_transmit_conditional(false, function(ply)
      if ply:can('moderator') then
        return false
      end
    end)
  end

  return false
end

--- Keeps players where they are when leaving observer mode if the 'observer_reset' config
-- is off.
-- @param player [Player]
-- @return [Boolean false if the player should not be moved back, nil otherwise]
function Observer:ShouldObserverReset(player)
  if !Config.get('observer_reset') then
    return false
  end
end
