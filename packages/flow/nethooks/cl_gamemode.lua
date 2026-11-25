--- Client-side receivers of the gamemode's network messages. They run the hooks that the
-- server asks for (`hook.run_client`), repeat `PlayerInitialSpawn`, `PlayerDisconnected`
-- and `PlayerModelChanged` on the client, and show notifications and the damage flash.
-- Notifications that arrive before the local player has been initialized, up to 32 of them,
-- are shown once it has been.

local IsValid = IsValid
local max_pending = 32
local pending_notifications = {}

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
  elseif #pending_notifications < max_pending then
    pending_notifications[#pending_notifications + 1] = { message, arguments, color }
  end
end)

--- Shows the notifications that have arrived before the local player was initialized.
hook.Add('PlayerInitialized', 'FluxPendingNotifications', function()
  local client = PLAYER

  if !IsValid(client) then return end

  for i = 1, #pending_notifications do
    local notification = pending_notifications[i]

    client:notify(notification[1], notification[2], notification[3])
    pending_notifications[i] = nil
  end
end)

Cable.receive('fl_player_take_damage', function()
  if IsValid(PLAYER) then
    PLAYER.last_damage = CurTime()
  end
end)
