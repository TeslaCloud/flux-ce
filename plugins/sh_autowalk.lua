PLUGIN:set_name('Auto Walk')
PLUGIN:set_author('NightAngel')
PLUGIN:set_description('Allows users to press a button to automatically walk forward.')

if SERVER then
  local check = {
    [IN_FORWARD] = true,
    [IN_BACK] = true,
    [IN_MOVELEFT] = true,
    [IN_MOVERIGHT] = true
  }

  --- Moves auto walking players forward at full speed.
  -- Turns auto walk off as soon as the player presses a movement key.
  -- @param actor [Player]
  -- @param move_data [CMoveData]
  -- @param cmd_data [CUserCmd]
  function PLUGIN:SetupMove(actor, move_data, cmd_data)
    if !actor:get_nv('auto_walk') then return end

    move_data:SetForwardSpeed(move_data:GetMaxSpeed())

    -- If they try to move, break the autowalk.
    for k, v in pairs(check) do
      if cmd_data:KeyDown(k) then
        actor:set_nv('auto_walk', false)

        break
      end
    end
  end

  -- So clients can bind this as they want.
  concommand.Add('toggleautowalk', function(actor)
    if hook.Run('CanPlayerAutoWalk', actor) != false then
      actor:set_nv('auto_walk', !actor:get_nv('auto_walk', false))
    end
  end)
else
-- Flux.hint:Add('Autowalk', 'Press 'B' to toggle auto walking.')

  -- We do this so there's no need to do an unnecessary check for if client or server in the hook itself.

  --- Moves the player forward at full speed while auto walk is on (clientside prediction).
  -- @param client [Player]
  -- @param move_data [CMoveData]
  -- @param cmd_data [CUserCmd]
  function PLUGIN:SetupMove(client, move_data, cmd_data)
    if !client:get_nv('auto_walk') then return end

    move_data:SetForwardSpeed(move_data:GetMaxSpeed())
  end

  Flux.Binds:add_bind('ToggleAutoWalk', 'toggleautowalk', KEY_N)
end
