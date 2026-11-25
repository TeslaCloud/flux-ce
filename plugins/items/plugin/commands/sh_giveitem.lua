--- The GiveItem command gives one or several players a number of items, at most 100 at a
-- time. The item is named by its whole ID or name.

CMD.name = 'GiveItem'
CMD.description = 'command.giveitem.description'
CMD.syntax = 'command.giveitem.syntax'
CMD.category = 'permission.categories.character_management'
CMD.arguments = 2
CMD.arg_types = { 'player', 'item', 'number' }
CMD.aliases = { 'chargiveitem', 'plygiveitem' }

local max_amount = 100

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

--- Gives the specified amount of an item to every target and notifies the staff about it,
-- naming how many items each target has got. A target whose inventory fills up gets the
-- items that fit, and the actor is told why the rest is missing.
-- @param actor [Player the player who ran the command]
-- @param targets [List<Player> players to give the item to]
-- @param item_name [String ID or name of the item]
-- @param amount=1 [Number amount of items to give, rounded down and kept between 1 and 100]
function CMD:on_run(actor, targets, item_name, amount)
  local item_obj = find_item(item_name)

  if !item_obj then
    Flux.Player:notify(actor, 'error.invalid_item', { item = item_name })

    return
  end

  amount = math.Clamp(math.floor(amount or 1), 1, max_amount)

  local receivers_by_amount = {}

  for _, target in ipairs(targets) do
    local success, error_text, given = target:give_item(item_obj.id, amount)

    given = given or 0

    if given > 0 then
      target:notify('notification.item_given', {
        amount = given,
        item = item_obj.name
      })

      local receivers = receivers_by_amount[given] or {}

      receivers[#receivers + 1] = target
      receivers_by_amount[given] = receivers
    end

    if !success then
      Flux.Player:notify(actor, error_text)
    end
  end

  for given, receivers in pairs(receivers_by_amount) do
    self:notify_staff('command.giveitem.message', {
      player = get_player_name(actor),
      target = util.player_list_to_string(receivers),
      amount = given,
      item = item_obj.name
    })
  end
end
