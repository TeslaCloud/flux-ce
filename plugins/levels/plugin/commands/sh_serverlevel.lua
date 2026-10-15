--- The `serverlevel` staff command works with the server level. `/serverlevel get` shows the
-- caller the server level, how far the server is into it and how long it has left until the
-- next one, together with the level floor and the level cap it sets for characters; it needs
-- the 'serverlevel_get' permission. `/serverlevel set <level>` puts the server at the very
-- start of a level by moving the time the server level is counted from, see
-- `Levels.set_server_level`; characters are brought in line with the new level cap and level
-- floor right away. Both work from the server console.

CMD.name = 'ServerLevel'
CMD.description = 'command.serverlevel.description'
CMD.category = 'permission.categories.server_management'
CMD.aliases = { 'serverlvl' }

local get = CMD:subcommand('get')
get.description = 'command.serverlevel.get.description'
get.permission_id = 'serverlevel_get'

--- Tells the caller the server level, the time spent at it and left until the next one, and
-- the level floor and level cap, or that they do not apply while the
-- `levels_server_progression` config is off.
-- @param actor [Player the player who ran the command, or an invalid entity for the console]
function get:on_run(actor)
  local level = Levels.get_server_level()
  local max_level = Levels.get_max_level()
  local eta = Levels.get_server_level_eta()

  if eta then
    local elapsed = Levels.get_server_level_progress()

    Flux.Player:notify(actor, 'command.serverlevel.get.message', {
      level = level,
      max_level = max_level,
      next_level = level + 1,
      elapsed = Flux.Lang:duration(elapsed),
      time = Flux.Lang:duration(math.max(eta, 1))
    })
  else
    Flux.Player:notify(actor, 'command.serverlevel.get.message_max', { level = level })
  end

  if Levels.is_server_progression_enabled() then
    Flux.Player:notify(actor, 'command.serverlevel.get.limits', {
      floor = Levels.get_level_floor(),
      cap = Levels.get_level_cap()
    })
  else
    Flux.Player:notify(actor, 'command.serverlevel.get.progression_off')
  end
end

local set = CMD:subcommand('set')
set.description = 'command.serverlevel.set.description'
set.syntax = 'command.serverlevel.set.syntax'
set.arguments = 1
set.arg_types = { 'number' }

--- Returns the translated description with the highest level filled in.
-- @return [String]
function set:get_description()
  return t(self.description, { max_level = Levels.get_max_level() })
end

--- Sets the server level and notifies staff.
-- @param actor [Player the player who ran the command, or an invalid entity for the console]
-- @param level [String new server level, parsed with tonumber, rounded and kept between -1
--   and the highest level]
function set:on_run(actor, level)
  level = tonumber(level)

  if !level or level != level then
    Flux.Player:notify(actor, 'error.invalid_value')

    return
  end

  level = math.clamp(math.Round(level), -1, Levels.get_max_level())

  if !Levels.set_server_level(level) then
    Flux.Player:notify(actor, 'error.invalid_value')

    return
  end

  self:notify_staff('command.serverlevel.set.message', {
    player = get_player_name(actor),
    level = level
  })
end
