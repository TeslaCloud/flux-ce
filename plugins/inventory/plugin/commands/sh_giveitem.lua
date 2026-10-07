CMD.name = 'GiveItem'
CMD.description = 'command.giveitem.description'
CMD.syntax = 'command.giveitem.syntax'
CMD.permission = 'moderator'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 2
CMD.player_arg = 1
CMD.aliases = { 'chargiveitem', 'plygiveitem' }

--- Gives the specified amount of an item to every target and notifies the staff about it.
-- @param player [Player the player who ran the command]
-- @param targets [Array<Player> players to give the item to]
-- @param item_name [String id or name of the item]
-- @param amount=1 [String/Number amount of items to give; converted to a number]
function CMD:on_run(player, targets, item_name, amount)
  local item_obj = Item.find(item_name)
  amount = tonumber(amount) or 1

  if item_obj then
    for k, v in ipairs(targets) do
      local success, error_text = v:give_item(item_obj.id, amount)

      if success then
        v:notify('notification.item_given', {
          amount = amount,
          item = item_obj.name
        })
      else
        player:notify(error_text)
      end
    end

    self:notify_staff('command.giveitem.message', {
      player = get_player_name(player),
      target = util.player_list_to_string(targets),
      amount = amount,
      item = item_obj.name
    })
  else
    player:notify('error.invalid_item', { item = item_name })
  end
end
