--- Staff command that bans and unbans characters. `/charban add <target>` bans the active
-- characters of one or more players: a banned character cannot be loaded or deleted by its
-- player. `/charban remove <character name>` lifts the ban of a character by its exact name;
-- the character does not have to be in use and its player does not have to be on the
-- server.

CMD.name = 'CharBan'
CMD.description = 'command.charban.description'
CMD.category = 'permission.categories.character_management'
CMD.alias = 'banchar'

local add = CMD:subcommand('add')
add.description = 'command.charban.add.description'
add.syntax = 'command.charban.add.syntax'
add.arguments = 1
add.arg_types = { 'player' }
add.immunity = true

--- Bans the active character of every target that has one and notifies staff. Bots and
-- characters that are already banned are skipped.
-- @param actor [Player the player who ran the command, or an invalid entity for the console]
-- @param targets [List<Player> players matched by the first command argument]
function add:on_run(actor, targets)
  local names = {}

  for _, v in ipairs(targets) do
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

  self:notify_staff('command.charban.add.message', {
    player = get_player_name(actor),
    target = table.concat(names, ', ')
  })
end

local remove = CMD:subcommand('remove')
remove.description = 'command.charban.remove.description'
remove.syntax = 'command.charban.remove.syntax'
remove.arguments = 1
remove.arg_types = { 'text' }

--- Unbans every banned character whose name is exactly the given one, ignoring letter case
-- and repeated whitespace, and notifies staff, or tells the caller that there is no such
-- character or that it is not banned. The characters of connected players are looked up
-- first, then the database.
-- @param actor [Player the player who ran the command, or an invalid entity for the console]
-- @param ... [Vararg words of the character name, joined with spaces]
-- @see [Characters.find_by_name]
function remove:on_run(actor, ...)
  local name = table.concat({ ... }, ' ')

  Characters.find_by_name(name, function(characters)
    local names = {}

    for _, v in ipairs(characters) do
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

    self:notify_staff('command.charban.remove.message', {
      player = get_player_name(actor),
      target = table.concat(names, ', ')
    })
  end)
end
