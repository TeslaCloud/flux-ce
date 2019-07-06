COMMAND.name = 'GiveItem'
COMMAND.description = 'command.giveitem.description'
COMMAND.syntax = 'command.giveitem.syntax'
COMMAND.permission = 'moderator'
COMMAND.category = 'permission.categories.character_management'
COMMAND.arguments = 2
COMMAND.player_arg = 1
COMMAND.aliases = { 'chargiveitem', 'plygiveitem' }

function COMMAND:on_run(player, targets, item_name, amount)
  local item_table = Item.find(item_name)
  amount = tonumber(amount) or 1

  if item_table then
    for k, v in ipairs(targets) do
      for i = 1, amount do
        v:give_item(item_table.id)
      end

      v:notify('notification.item_given', {
        amount = amount,
        item = item_table.name
      })
    end

    self:notify_staff('command.giveitem.message', {
      player = get_player_name(player),
      target = util.player_list_to_string(targets),
      amount = amount,
      item = item_table.name
    })
  else
    player:notify('error.invalid_item', { item = item_name })
  end
end
