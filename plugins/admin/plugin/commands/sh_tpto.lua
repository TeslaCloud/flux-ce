--- The Tpto command teleports the caller to the targeted player. Allowed for assistants by
-- default.

CMD.name = 'Tpto'
CMD.description = 'command.tpto.description'
CMD.syntax = 'command.tpto.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.administration'
CMD.arguments = 1
CMD.player_arg = 1
CMD.alias = 'goto'

--- Teleports the caller to the targeted player and notifies staff.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> matched players; only the first one is used]
function CMD:on_run(actor, targets)
  local target = targets[1]

  if IsValid(target) then
    actor:teleport(target:GetPos())
  end

  self:notify_staff('command.tpto.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string({ target })
  })
end
