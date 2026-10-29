--- Client-side receivers that open the interaction menu when the local player uses a player
-- or an entity.

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
