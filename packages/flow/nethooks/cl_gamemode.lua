--- Client-side receivers of the gamemode's network messages. They run the hooks that the
-- server asks for (`hook.run_client`), repeat `PlayerInitialSpawn`, `PlayerDisconnected`
-- and `PlayerModelChanged` on the client, and show notifications and the damage flash.

local IsValid = IsValid

Cable.receive('fl_hook_run_cl', function(hook_name, ...)
  hook.Run(hook_name, ...)
end)

Cable.receive('fl_player_initial_spawn', function(ply_index)
  util.wait_for_ent(ply_index, function(target)
    --- GMod's `PlayerInitialSpawn` hook, which the game only runs on the server. Flux runs
    -- it on every client as well when the server announces a newly connected player; bots
    -- are not announced. The hook waits for the client to receive the entity of the
    -- player (see `util.wait_for_ent`) and is not run if the entity never arrives.
    -- @param actor [Player The player who has joined]
    hook.Run('PlayerInitialSpawn', target)
  end)
end)

Cable.receive('fl_player_disconnected', function(ply_index)
  --- GMod's `PlayerDisconnected` hook, which the game only runs on the server. Flux runs
  -- it on every client as well when the server announces that a player has left.
  -- @param actor [Player The player who is leaving. The entity is not valid if the client
  --   has already lost it]
  hook.Run('PlayerDisconnected', Entity(ply_index))
end)

Cable.receive('fl_player_model_changed', function(ply_index, new_model, old_model)
  util.wait_for_ent(ply_index, function(target)
    hook.Run('PlayerModelChanged', target, new_model, old_model)
  end)
end)

Cable.receive('fl_notification', function(message, arguments, color)
  local client = PLAYER

  if IsValid(client) and client:has_initialized() then
    client:notify(message, arguments, color)
  end
end)

Cable.receive('fl_player_take_damage', function()
  if IsValid(PLAYER) then
    PLAYER.last_damage = CurTime()
  end
end)
