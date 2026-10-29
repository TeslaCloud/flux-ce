--- The Tpto command teleports the caller to the targeted player.

CMD.name = 'Tpto'
CMD.description = 'command.tpto.description'
CMD.syntax = 'command.tpto.syntax'
CMD.category = 'permission.categories.administration'
CMD.arguments = 1
CMD.arg_types = { 'player' }
CMD.no_console = true
CMD.alias = 'goto'

--- Teleports the caller to the targeted player and notifies staff.
-- @param actor [Player the caller]
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
