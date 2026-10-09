--- Staff command that bans the active characters of one or more players. A banned character
-- cannot be loaded or deleted by its player until it is unbanned with CharUnban.

CMD.name = 'CharBan'
CMD.description = 'command.charban.description'
CMD.syntax = 'command.charban.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 1
CMD.immunity = true
CMD.alias = 'banchar'

--- Bans the active character of every target that has one and notifies staff. Bots and
-- characters that are already banned are skipped.
-- @param actor [Player the player who ran the command, or an invalid entity for the console]
-- @param targets [List<Player> players matched by the first command argument]
function CMD:on_run(actor, targets)
  local names = {}

  for k, v in ipairs(targets) do
    local character = !v:IsBot() and v:is_character_loaded() and v:get_character()

    if character and !tobool(character.banned) then
      table.insert(names, character.name)

      Characters.set_banned(character, true)
    end
  end

  if #names == 0 then
    Flux.Player:notify(actor, 'error.character.nobody_to_ban')

    return
  end

  self:notify_staff('command.charban.message', {
    player = get_player_name(actor),
    target = table.concat(names, ', ')
  })
end
