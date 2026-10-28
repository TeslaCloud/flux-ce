--- The GMPossess command lets a gamemaster possess a pool character by its whole name, where
-- they stand.

CMD.name = 'GMPossess'
CMD.description = 'command.gmpossess.description'
CMD.syntax = 'command.gmpossess.syntax'
CMD.category = 'permission.categories.administration'
CMD.arguments = 1
CMD.arg_types = { 'gm_character' }
CMD.no_console = true

--- Finds the pool character with the given name and possesses it for the caller, telling them
-- the outcome.
-- @param actor [Player the caller]
-- @param ... [Vararg words of the character name]
function CMD:on_run(actor, ...)
  if !Gamemastery.is_gamemaster(actor) then
    actor:notify('error.gamemastery.no_permission')

    return
  end

  local name = table.concat({ ... }, ' ')
  local character, ambiguous = Gamemastery.find_character_by_name(name)

  if !character then
    actor:notify(ambiguous ? 'error.gamemastery.ambiguous' : 'error.gamemastery.not_found', { name = name })

    return
  end

  local success, reason, arguments = Gamemastery.possess(actor, character)

  if success then
    actor:notify('notification.gamemastery.possessed', { name = character.name })
  else
    actor:notify(reason, arguments)
  end
end
