--- The `level` staff command works with the levels of the targeted players' characters.
-- `/level get <player>` shows the caller the level of the character, its experience and the
-- experience it still needs for the next level, or the level cap that holds it back when it
-- has kept enough experience for the next level at the cap; it needs the 'level_get'
-- permission. `/level set <player> <level>` sets the level of the characters: their
-- experience is reset to 0 and their unspent points are worked out again for the new level.
-- The level cap of the server level does not bind it, so staff can set a level above the cap,
-- but the level floor does: a level below the floor is raised to it.

CMD.name = 'Level'
CMD.description = 'command.level.description'
CMD.category = 'permission.categories.character_management'
CMD.aliases = { 'charlevel' }

local get = CMD:subcommand('get')
get.description = 'command.level.get.description'
get.syntax = 'command.level.get.syntax'
get.permission_id = 'level_get'
get.arguments = 1
get.arg_types = { 'player' }

--- Tells the caller the level and the experience of the target's character, or the level
-- cap when the character is held at it with enough experience kept for the next level.
-- @param actor [Player the player who ran the command, or an invalid entity for the console]
-- @param targets [List<Player> matched players; only the first one is used]
function get:on_run(actor, targets)
  local target = targets[1]

  if !IsValid(target) then return end

  local target_name = target:name()

  if !target:is_character_loaded() then
    Flux.Player:notify(actor, 'error.levels.no_character', { target = target_name })

    return
  end

  local level = target:get_level()
  local max_level = Levels.get_max_level()

  if level >= max_level then
    Flux.Player:notify(actor, 'command.level.get.message_max', {
      target = target_name,
      level = level
    })

    return
  end

  local experience = target:get_experience()
  local cap = Levels.get_level_cap()

  if Levels.is_server_progression_enabled() and level == cap and target:get_experience_to_level() <= 0 then
    Flux.Player:notify(actor, 'command.level.get.message_capped', {
      target = target_name,
      level = level,
      max_level = max_level,
      experience = experience,
      cap = cap
    })

    return
  end

  Flux.Player:notify(actor, 'command.level.get.message', {
    target = target_name,
    level = level,
    max_level = max_level,
    experience = experience,
    needed = Levels.get_experience_for_level(level),
    remaining = target:get_experience_to_level()
  })
end

local set = CMD:subcommand('set')
set.description = 'command.level.set.description'
set.syntax = 'command.level.set.syntax'
set.arguments = 2
set.arg_types = { 'player', 'number' }

--- Returns the translated description with the highest level and the level floor filled in.
-- @return [String]
function set:get_description()
  return t(self.description, { max_level = Levels.get_max_level(), floor = Levels.get_level_floor() })
end

--- Sets the level of every target that has an active character, then notifies the targets
-- and staff.
-- @param actor [Player the player who ran the command, or an invalid entity for the console]
-- @param targets [List<Player> players matched by the first command argument]
-- @param level [String new level, parsed with tonumber and kept between the level floor and
--   the highest level]
function set:on_run(actor, targets, level)
  level = tonumber(level)

  if !level or level != level then
    Flux.Player:notify(actor, 'error.invalid_value')

    return
  end

  level = math.clamp(math.Round(level), Levels.get_level_floor(), Levels.get_max_level())

  local changed = {}

  for _, target in ipairs(targets) do
    if target:is_character_loaded() then
      target:set_level(level)
      target:notify('notification.levels.level_set', { level = level })

      table.insert(changed, target)
    end
  end

  if #changed == 0 then
    Flux.Player:notify(actor, 'error.levels.no_character', { target = util.player_list_to_string(targets) })

    return
  end

  self:notify_staff('command.level.set.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(changed),
    level = level
  })
end
