--- The Send command teleports the targeted players to another player. It complements Tp,
-- which brings players to the spot the caller is looking at, and Tpto, which takes the
-- caller to a player. Allowed for assistants by default.

CMD.name = 'Send'
CMD.description = 'command.send.description'
CMD.syntax = 'command.send.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.administration'
CMD.arguments = 2
CMD.immunity = true
CMD.aliases = { 'sendto', 'plysend', 'plyteleportto' }

--- Teleports the targeted players to the destination player and notifies them and staff.
-- The previous position of everyone who is moved is kept for the Return command. The
-- destination is found like any other command target, but is not checked for immunity,
-- since nothing happens to them; if it matches several players the first one is used.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players to teleport]
-- @param destination [String name or target selector of the player to teleport them to]
function CMD:on_run(actor, targets, destination)
  local found = Flux.Command:str_to_player(actor, tostring(destination))
  local goal = istable(found) and found[1]

  if !IsValid(goal) then
    Flux.Player:notify(actor, 'error.command.player_invalid', { player = tostring(destination) })

    return
  end

  local pos = goal:GetPos()
  local moved = {}

  for k, v in ipairs(targets) do
    if IsValid(v) and v != goal then
      v:teleport(pos)
      v:notify('notification.tp')

      table.insert(moved, v)
    end
  end

  if #moved == 0 then
    Flux.Player:notify(actor, 'error.send_same')

    return
  end

  self:notify_staff('command.send.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(moved),
    destination = goal:name()
  })
end
