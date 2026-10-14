--- The CharSetLevel command sets the level of the targeted players' characters. Their
-- experience is reset to 0 and their unspent points are worked out again for the new level.
-- The level cap of the server level does not bind it, so staff can set a level above the
-- cap, but the level floor does: a level below the floor is raised to it. Allowed for admins
-- by default.

CMD.name = 'CharSetLevel'
CMD.description = 'command.charsetlevel.description'
CMD.syntax = 'command.charsetlevel.syntax'
CMD.permission = 'admin'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 2
CMD.player_arg = 1
CMD.aliases = { 'setlevel', 'charlevelset' }

--- Returns the translated command description with the highest level and the level floor
-- filled in.
-- @return [String]
function CMD:get_description()
  return t(self.description, { max_level = Levels.get_max_level(), floor = Levels.get_level_floor() })
end

--- Sets the level of every target that has an active character, then notifies the targets
-- and staff.
-- @param actor [Player the player who ran the command, or an invalid entity for the console]
-- @param targets [List<Player> players matched by the first command argument]
-- @param level [String new level, parsed with tonumber and kept between the level floor and
--   the highest level]
function CMD:on_run(actor, targets, level)
  level = tonumber(level)

  if !level or level != level then
    Flux.Player:notify(actor, 'error.invalid_value')

    return
  end

  level = math.clamp(math.Round(level), Levels.get_level_floor(), Levels.get_max_level())

  local changed = {}

  for k, v in ipairs(targets) do
    if v:is_character_loaded() then
      v:set_level(level)
      v:notify('notification.levels.level_set', { level = level })

      table.insert(changed, v)
    end
  end

  if #changed == 0 then
    Flux.Player:notify(actor, 'error.levels.no_character', { target = util.player_list_to_string(targets) })

    return
  end

  self:notify_staff('command.charsetlevel.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(changed),
    level = level
  })
end
