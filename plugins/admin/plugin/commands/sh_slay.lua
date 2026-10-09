--- The Slay command kills the targeted players. Allowed for assistants by default.

CMD.name = 'Slay'
CMD.description = 'command.slay.description'
CMD.syntax = 'command.slay.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.player_management'
CMD.arguments = 1
CMD.immunity = true
CMD.aliases = { 'plyslay', 'plykill' }

--- Kills the targeted players who are alive and notifies them and staff. The caller is told
-- if none of the targets is alive.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players to kill]
function CMD:on_run(actor, targets)
  local slain = {}

  for k, v in ipairs(targets) do
    if v:Alive() then
      v:Kill()
      v:notify('notification.slay', {
        player = IsValid(actor) and actor or get_player_name(actor)
      })

      table.insert(slain, v)
    end
  end

  if #slain == 0 then
    Flux.Player:notify(actor, 'error.slay')

    return
  end

  self:notify_staff('command.slay.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(slain)
  })
end
