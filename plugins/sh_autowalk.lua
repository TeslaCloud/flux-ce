--- Auto Walk lets players walk forward without holding a key.
-- It is toggled with the `toggleautowalk` console command, which the plugin binds to the N key
-- by default, and stops as soon as the player presses a movement key. Plugins can forbid it
-- through the `CanPlayerAutoWalk` hook. The state is networked as the `auto_walk` variable of
-- the player.

PLUGIN:set_name('Auto Walk')
PLUGIN:set_author('NightAngel')
PLUGIN:set_description('Allows users to press a button to automatically walk forward.')

if SERVER then
  local movement_keys = bit.bor(IN_FORWARD, IN_BACK, IN_MOVELEFT, IN_MOVERIGHT)

  --- Moves auto walking players forward at full speed.
  -- Turns auto walk off as soon as the player presses a movement key.
  -- @param actor [Player]
  -- @param move_data [CMoveData]
  -- @param cmd_data [CUserCmd]
  function PLUGIN:SetupMove(actor, move_data, cmd_data)
    if !actor:get_nv('auto_walk') then return end

    move_data:SetForwardSpeed(move_data:GetMaxSpeed())

    -- If they try to move, break the autowalk.
    if bit.band(cmd_data:GetButtons(), movement_keys) != 0 then
      actor:set_nv('auto_walk', false)
    end
  end

  -- So clients can bind this as they want.
  concommand.Add('toggleautowalk', function(actor)
    --- Asks whether a player may toggle auto walk.
    -- Called on the server when the player runs the `toggleautowalk` command, for turning it
    -- off as well as on.
    -- @param actor [Player The player who wants to toggle auto walk]
    -- @return [Boolean Return false to prevent the toggle]
    if hook.Run('CanPlayerAutoWalk', actor) != false then
      actor:set_nv('auto_walk', !actor:get_nv('auto_walk', false))
    end
  end)
else
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
