--- Staff command that makes the characters of players forget the characters of other
-- players, as if they had never been introduced to them.

CMD.name = 'CharForget'
CMD.description = 'command.charforget.description'
CMD.syntax = 'command.charforget.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 2
CMD.immunity = true
CMD.aliases = { 'forget', 'plyforget' }

--- Makes the active character of every target forget the characters of the players that
-- the rest of the arguments name, tells the targets who they have forgotten and notifies
-- staff. The caller is told when there was nobody to forget.
-- @param actor [Player the player who ran the command, or an invalid entity for the console]
-- @param targets [List<Player> players matched by the first command argument]
-- @param ... [Vararg words of the name or target selector of the players to forget]
function CMD:on_run(actor, targets, ...)
  local selector = table.concat({ ... }, ' ')
  local forgotten = Flux.Command:str_to_player(actor, selector)

  if !istable(forgotten) or #forgotten == 0 then
    Flux.Player:notify(actor, 'error.command.player_invalid', { player = tostring(selector) })

    return
  end

  local count = 0

  for k, v in ipairs(targets) do
    for k2, v2 in ipairs(forgotten) do
      local known_name = v:get_recognize(v2)

      if known_name and v:remove_recognize(v2) then
        count = count + 1

        v:notify('notification.recognize.forgotten', { name = tostring(known_name) }, Color('salmon'))
      end
    end
  end

  if count == 0 then
    Flux.Player:notify(actor, 'error.recognize.nothing_to_forget')

    return
  end

  self:notify_staff('command.charforget.message', {
    player = tostring(get_player_name(actor)),
    target = tostring(util.player_list_to_string(targets)),
    forgotten = tostring(util.player_list_to_string(forgotten))
  })
end
