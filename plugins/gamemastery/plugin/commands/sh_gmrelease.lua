--- The GMRelease command makes a gamemaster stop playing the pool character they possess and
-- puts them back into gamemaster mode where they stand. Allowed for gamemasters by default.

CMD.name = 'GMRelease'
CMD.description = 'command.gmrelease.description'
CMD.permission = 'gamemaster'
CMD.category = 'permission.categories.administration'
CMD.alias = 'unpossess'
CMD.no_console = true

--- Releases the pool character of the caller and tells them the outcome.
-- @param actor [Player the caller]
function CMD:on_run(actor)
  if !Gamemastery.is_gamemaster(actor) then
    actor:notify('error.gamemastery.no_permission')

    return
  end

  local success, result = Gamemastery.release(actor)

  if success then
    actor:notify('notification.gamemastery.released', { name = result.name })
  else
    actor:notify(result)
  end
end
