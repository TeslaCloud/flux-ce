--- The ServerLevel command shows the caller the server level, how far the server is into it and
-- how long it has left until the next one, together with the level floor and the level cap it
-- sets for characters. Works from the server console.

CMD.name = 'ServerLevel'
CMD.description = 'command.serverlevel.description'
CMD.category = 'permission.categories.server_management'
CMD.aliases = { 'serverlvl', 'checkserverlevel', 'getserverlevel' }

--- Tells the caller the server level, the time spent at it and left until the next one, and
-- the level floor and level cap, or that they do not apply while the
-- `levels_server_progression` config is off.
-- @param actor [Player the player who ran the command, or an invalid entity for the console]
function CMD:on_run(actor)
  local level = Levels.get_server_level()
  local max_level = Levels.get_max_level()
  local eta = Levels.get_server_level_eta()

  if eta then
    local elapsed = Levels.get_server_level_progress()

    Flux.Player:notify(actor, 'command.serverlevel.message', {
      level = level,
      max_level = max_level,
      next_level = level + 1,
      elapsed = Flux.Lang:duration(elapsed),
      time = Flux.Lang:duration(math.max(eta, 1))
    })
  else
    Flux.Player:notify(actor, 'command.serverlevel.message_max', { level = level })
  end

  if Levels.is_server_progression_enabled() then
    Flux.Player:notify(actor, 'command.serverlevel.limits', {
      floor = Levels.get_level_floor(),
      cap = Levels.get_level_cap()
    })
  else
    Flux.Player:notify(actor, 'command.serverlevel.progression_off')
  end
end
