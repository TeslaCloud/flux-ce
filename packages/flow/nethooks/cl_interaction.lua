--- Client-side receivers that open the interaction menu when the local player uses a player
-- or an entity.

--- Opens a list of interaction options as a menu in the middle of the screen.
-- @param options [List<Map> options, see `util.build_menu`; nothing opens when it is empty]
local function open_interactions(options)
  if #options == 0 then return end

  local interaction_menu = util.build_menu(options)

  interaction_menu:Open()
  interaction_menu:Center()
end

Cable.receive('fl_player_interact', function(target)
  local options = {}

  --- Called on the client when the local player presses the use key on another player, to
  -- fill the interaction menu. Handlers add options to `options` or remove the ones that
  -- other handlers have added, in place, and return nothing. The menu opens in the middle
  -- of the screen if the list holds anything once every handler has run. The server
  -- triggers this at most once a second for each player.
  -- ```
  -- function MyPlugin:AdjustPlayerInteractions(options, target)
  --   options[#options + 1] = {
  --     id = 'wave',
  --     text = t'ui.my_plugin.wave',
  --     icon = 'icon16/user.png',
  --     callback = function() Cable.send('fl_wave', target) end
  --   }
  -- end
  -- ```
  -- @param options [List<Map> The options of the menu, see `util.build_menu`]
  -- @param target [Player The player being used]
  hook.Run('AdjustPlayerInteractions', options, target)

  open_interactions(options)
end)

Cable.receive('fl_entity_interact', function(entity)
  local options = {}

  --- Called on the client when the local player presses the use key on an entity that is
  -- not a player, to fill the interaction menu. Handlers add options to `options` or remove
  -- the ones that other handlers have added, in place, and return nothing. The menu opens
  -- in the middle of the screen if the list holds anything once every handler has run. The
  -- server triggers this at most once a second for each player.
  -- @param options [List<Map> The options of the menu, see `util.build_menu`]
  -- @param entity [Entity The entity being used]
  hook.Run('AdjustEntityInteractions', options, entity)

  open_interactions(options)
end)
