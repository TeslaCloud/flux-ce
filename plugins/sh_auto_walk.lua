--- Auto Walk lets players walk forward without holding a key.
-- It is toggled with the `toggleautowalk` console command, which the plugin binds to the N key
-- by default, and stops as soon as the player presses a movement key, spawns or starts to
-- noclip. A frozen player cannot turn it on, and plugins can forbid it through the
-- `PlayerCanAutoWalk` hook. The state is networked as the `auto_walk` variable of the player.

PLUGIN:set_name('Auto Walk')
PLUGIN:set_author('NightAngel')
PLUGIN:set_description('Allows users to press a button to automatically walk forward.')

local movement_keys = IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT

--- Moves auto walking players forward at full speed, on the server and in the prediction of
-- the client. The server turns auto walk off as soon as the player presses a movement key.
-- @param actor [Player]
-- @param move_data [CMoveData]
-- @param cmd_data [CUserCmd]
function PLUGIN:SetupMove(actor, move_data, cmd_data)
  if !actor:get_nv('auto_walk') then return end

  move_data:SetForwardSpeed(move_data:GetMaxSpeed())

  if SERVER and (cmd_data:GetButtons() & movement_keys) != 0 then
    actor:set_nv('auto_walk', false)
  end
end

if SERVER then
  --- Turns auto walk off for a player who has spawned.
  -- @param actor [Player]
  function PLUGIN:PlayerSpawn(actor)
    if actor:get_nv('auto_walk') then
      actor:set_nv('auto_walk', false)
    end
  end

  --- Turns auto walk off for a player who toggles noclip.
  -- @param actor [Player]
  -- @param _state [Boolean whether the player wants to noclip]
  function PLUGIN:PlayerNoClip(actor, _state)
    if actor:get_nv('auto_walk') then
      actor:set_nv('auto_walk', false)
    end
  end

  concommand.Add('toggleautowalk', function(actor)
    if !IsValid(actor) then return end

    local cur_time = CurTime()

    if (actor.fl_next_auto_walk or 0) > cur_time then return end

    actor.fl_next_auto_walk = cur_time + 0.25

    local enable = !actor:get_nv('auto_walk', false)

    if enable and actor:is_frozen() then return end

    --- Asks whether a player may toggle auto walk.
    -- Called on the server when the player runs the `toggleautowalk` command, for turning it
    -- off as well as on. A frozen player is refused turning it on before this is asked.
    -- @param actor [Player The player who wants to toggle auto walk]
    -- @return [Boolean Return false to prevent the toggle]
    if hook.Run('PlayerCanAutoWalk', actor) != false then
      actor:set_nv('auto_walk', enable)
    end
  end)
else
  Flux.Binds:add_bind('ToggleAutoWalk', 'toggleautowalk', KEY_N)
end
