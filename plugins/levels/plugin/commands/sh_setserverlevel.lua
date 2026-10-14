--- The SetServerLevel command puts the server at the very start of a level by moving the
-- time the server level is counted from, see `Levels.set_server_level`. Characters are
-- brought in line with the new level cap and level floor right away. Allowed for admins by
-- default.

CMD.name = 'SetServerLevel'
CMD.description = 'command.setserverlevel.description'
CMD.syntax = 'command.setserverlevel.syntax'
CMD.permission = 'admin'
CMD.category = 'permission.categories.server_management'
CMD.arguments = 1
CMD.aliases = { 'serverlevelset', 'setserverlvl' }

--- Returns the translated command description with the highest level filled in.
-- @return [String]
function CMD:get_description()
  return t(self.description, { max_level = Levels.get_max_level() })
end

--- Sets the server level and notifies staff.
-- @param actor [Player the player who ran the command, or an invalid entity for the console]
-- @param level [String new server level, parsed with tonumber, rounded and kept between -1
--   and the highest level]
function CMD:on_run(actor, level)
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

  self:notify_staff('command.setserverlevel.message', {
    player = get_player_name(actor),
    level = level
  })
end
