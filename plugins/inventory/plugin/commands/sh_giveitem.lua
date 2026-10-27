--- The GiveItem command gives one or several players a number of items. The item is named by
-- its whole ID or name.

CMD.name = 'GiveItem'
CMD.description = 'command.giveitem.description'
CMD.syntax = 'command.giveitem.syntax'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 2
CMD.arg_types = { 'player', 'item', 'number' }
CMD.aliases = { 'chargiveitem', 'plygiveitem' }

--- Finds an item template by its whole ID, else by its whole name, ignoring letter case. The
-- name may be given as the language phrase the item is registered with or as its translation.
-- @param word [String the typed item]
-- @return [ItemBase the item template, or nil if no item has this ID or name]
local function find_item(word)
  local lowered = word:utf8lower()
  local items = Item.all()

  if items[word] then
    return items[word]
  end

  for item_id, template in pairs(items) do
    if isstring(item_id) and item_id:utf8lower() == lowered then
      return template
    end
  end

  for _, template in pairs(items) do
    for _, name in ipairs({ template.name, template.print_name }) do
      if isstring(name) and (name:utf8lower() == lowered or t(name):utf8lower() == lowered) then
        return template
      end
    end
  end
end

--- Gives the specified amount of an item to every target and notifies the staff about it.
-- @param actor [Player the player who ran the command]
-- @param targets [List<Player> players to give the item to]
-- @param item_name [String ID or name of the item]
-- @param amount=1 [String amount of items to give, converted to a number]
function CMD:on_run(actor, targets, item_name, amount)
  local item_obj = find_item(item_name)

  if !item_obj then
    Flux.Player:notify(actor, 'error.invalid_item', { item = item_name })

    return
  end

  amount = math.floor(tonumber(amount) or 1)

  if amount != amount or amount < 1 then
    amount = 1
  end

  for _, target in ipairs(targets) do
    local success, error_text = target:give_item(item_obj.id, amount)

    if success then
      target:notify('notification.item_given', {
        amount = amount,
        item = item_obj.name
      })
    else
      Flux.Player:notify(actor, error_text)
    end
  end

  self:notify_staff('command.giveitem.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(targets),
    amount = amount,
    item = item_obj.name
  })
end
