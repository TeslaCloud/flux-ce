--- Client-side receivers of the gamemode's network messages. They run the hooks that the
-- server asks for (`hook.run_client`), repeat `PlayerInitialSpawn`, `PlayerDisconnected`
-- and `PlayerModelChanged` on the client, show notifications and the damage flash, play
-- the sounds that the server starts and stops, and open the interaction menu when the
-- local player uses a player or an entity.

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
  PLAYER.last_damage = CurTime()
end)

Cable.receive('fl_sound_play', function(path)
  if isstring(path) then
    surface.PlaySound(path)
  end
end)

Cable.receive('fl_sound_start', function(id, path, volume)
  local client = LocalPlayer()

  if IsValid(client) then
    client:start_sound(id, path, volume)
  end
end)

Cable.receive('fl_sound_stop', function(id, fade_out)
  local client = LocalPlayer()

  if IsValid(client) then
    client:stop_sound(id, fade_out)
  end
end)

Cable.receive('fl_player_interact', function(target)
  local interaction_menu = DermaMenu()

  --- Called on the client when the local player presses the use key on another player, to
  -- fill the interaction menu. The menu opens in the middle of the screen if a handler
  -- has added anything to it and is removed otherwise. The server triggers this at most
  -- once a second for each player.
  -- @param menu [Panel The `DermaMenu` to add options to]
  -- @param target [Player The player being used]
  hook.Run('CreatePlayerInteractions', interaction_menu, target)

  if interaction_menu:ChildCount() > 0 then
    interaction_menu:Open()
    interaction_menu:Center()
  else
    interaction_menu:safe_remove()
  end
end)

Cable.receive('fl_entity_interact', function(entity)
  local interaction_menu = DermaMenu()

  --- Called on the client when the local player presses the use key on an entity that is
  -- not a player, to fill the interaction menu. The menu opens in the middle of the
  -- screen if a handler has added anything to it and is removed otherwise. The server
  -- triggers this at most once a second for each player.
  -- @param menu [Panel The `DermaMenu` to add options to]
  -- @param entity [Entity The entity being used]
  hook.Run('CreateEntityInteractions', interaction_menu, entity)

  if interaction_menu:ChildCount() > 0 then
    interaction_menu:Open()
    interaction_menu:Center()
  else
    interaction_menu:safe_remove()
  end
end)
