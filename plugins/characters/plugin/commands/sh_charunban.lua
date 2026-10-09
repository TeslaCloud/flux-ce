--- Staff command that unbans a character by its name. The character does not have to be in
-- use and its player does not have to be on the server.

CMD.name = 'CharUnban'
CMD.description = 'command.charunban.description'
CMD.syntax = 'command.charunban.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 1
CMD.alias = 'unbanchar'

--- Unbans every banned character with the given name and notifies staff, or tells the caller
-- that there is no such character or that it is not banned. The characters of connected
-- players are looked up first, then the database.
-- @param actor [Player the player who ran the command, or an invalid entity for the console]
-- @param ... [Vararg words of the character name, joined with spaces]
function CMD:on_run(actor, ...)
  local name = table.concat({ ... }, ' ')

  Characters.find_by_name(name, function(characters)
    local names = {}

    for k, v in ipairs(characters) do
      if tobool(v.banned) then
        table.insert(names, v.name)

        Characters.set_banned(v, false)
      end
    end

    if #names == 0 then
      Flux.Player:notify(
        actor,
        #characters == 0 and 'error.character.not_found' or 'error.character.not_banned',
        { name = name }
      )

      return
    end

    self:notify_staff('command.charunban.message', {
      player = get_player_name(actor),
      target = table.concat(names, ', ')
    })
  end)
end
