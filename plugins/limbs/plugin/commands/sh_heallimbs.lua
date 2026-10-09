--- Staff command that heals every limb of the targeted players. Allowed for assistants by
-- default.

CMD.name = 'HealLimbs'
CMD.description = 'command.heallimbs.description'
CMD.syntax = 'command.heallimbs.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 1
CMD.immunity = true
CMD.aliases = { 'charheallimbs', 'plyheallimbs' }

--- Clears the limb damage of every target and notifies them and staff.
-- @param actor [Player the player who ran the command, or an invalid entity for the console]
-- @param targets [List<Player> players matched by the first command argument]
function CMD:on_run(actor, targets)
  for k, v in ipairs(targets) do
    Limbs:reset(v)

    v:notify('command.heallimbs.notification')
  end

  self:notify_staff('command.heallimbs.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(targets)
  })
end
