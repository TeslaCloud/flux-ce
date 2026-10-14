--- Staff command that clears the recognitions of the active characters of players: the
-- characters they know, the characters that know them, or both.

CMD.name = 'CharClearRecognition'
CMD.description = 'command.charclearrecognition.description'
CMD.syntax = 'command.charclearrecognition.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 1
CMD.immunity = true
CMD.aliases = { 'clearrecognition', 'clearrecog' }

--- What the second argument of the command can be.
local modes = {
  own = true,
  others = true,
  all = true
}

--- Clears the recognitions of the active character of every target that has one and
-- notifies staff. In the 'own' mode, which is the default, the character forgets everyone
-- and its player is told so; in the 'others' mode every other character, loaded or not,
-- forgets the character; the 'all' mode does both.
-- @param actor [Player the player who ran the command, or an invalid entity for the console]
-- @param targets [List<Player> players matched by the first command argument]
-- @param mode='own' [String 'own', 'others' or 'all']
function CMD:on_run(actor, targets, mode)
  mode = isstring(mode) and mode:utf8lower() or 'own'

  if !modes[mode] then
    Flux.Player:notify(actor, 'error.recognize.invalid_mode', { mode = tostring(mode) })

    return
  end

  local names = {}

  for k, v in ipairs(targets) do
    if !v:IsBot() and v:is_character_loaded() then
      if mode != 'others' then
        v:clear_recognizes()
        v:notify('notification.recognize.forgot_everyone', nil, Color('salmon'))
      end

      if mode != 'own' then
        Recognizes:forget_character(v:get_character_id())
      end

      table.insert(names, tostring(v:name(true)))
    end
  end

  if #names == 0 then
    Flux.Player:notify(actor, 'error.recognize.no_character')

    return
  end

  self:notify_staff('command.charclearrecognition.message.'..mode, {
    player = tostring(get_player_name(actor)),
    target = table.concat(names, ', ')
  })
end
