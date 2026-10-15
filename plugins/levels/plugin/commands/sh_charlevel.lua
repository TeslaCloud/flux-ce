--- The CharLevel command shows the caller the level of the targeted player's character, its
-- experience and the experience it still needs for the next level, or the level cap that holds
-- it back when it has kept enough experience for the next level at the cap.

CMD.name = 'CharLevel'
CMD.description = 'command.charlevel.description'
CMD.syntax = 'command.charlevel.syntax'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 1
CMD.player_arg = 1
CMD.aliases = { 'checklevel', 'charchecklevel', 'getlevel' }

--- Tells the caller the level and the experience of the target's character, or the level
-- cap when the character is held at it with enough experience kept for the next level.
-- @param actor [Player the player who ran the command, or an invalid entity for the console]
-- @param targets [List<Player> matched players; only the first one is used]
function CMD:on_run(actor, targets)
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
    Flux.Player:notify(actor, 'command.charlevel.message_max', {
      target = target_name,
      level = level
    })

    return
  end

  local experience = target:get_experience()
  local cap = Levels.get_level_cap()

  if Levels.is_server_progression_enabled() and level == cap and target:get_experience_to_level() <= 0 then
    Flux.Player:notify(actor, 'command.charlevel.message_capped', {
      target = target_name,
      level = level,
      max_level = max_level,
      experience = experience,
      cap = cap
    })

    return
  end

  Flux.Player:notify(actor, 'command.charlevel.message', {
    target = target_name,
    level = level,
    max_level = max_level,
    experience = experience,
    needed = Levels.get_experience_for_level(level),
    remaining = target:get_experience_to_level()
  })
end
