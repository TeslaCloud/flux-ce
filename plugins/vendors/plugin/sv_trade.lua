--- Purchases and sales: carries out the trades that the trade panel asks for, checking the
-- session of the customer, the stock and the money of both sides and the room in the
-- inventory of the customer.

local trade_interval = 0.2

--- Checks the things that every trade starts with: the session of the player, the time since
-- their last trade and the currency of the vendor.
-- @param actor [Player]
-- @param vendor [Entity]
-- @return [Map the session of the player, or nil if no trade may happen right now]
local function begin_trade(actor, vendor)
  if !IsValid(actor) then return end

  local session = Vendors:check_session(actor, vendor)

  if !session then return end

  local cur_time = CurTime()

  if actor.next_vendor_trade and actor.next_vendor_trade > cur_time then return end

  actor.next_vendor_trade = cur_time + trade_interval

  if !Currencies:find_currency(vendor.vendor_data.currency) then
    actor:notify('error.invalid_currency')

    return
  end

  return session
end

--- Sells an item of a vendor to a player who is trading with it. Refused if the vendor does
-- not sell the item or has none left, if the PlayerCanBuyFromVendor hook vetoes it, if the
-- player cannot afford the item, if the CanItemTransfer hook keeps it out of their default
-- inventory (as it does while that inventory is disabled) or if they have no room for it,
-- where the hook is given the template of the item. Otherwise a new item instance goes to
-- the default inventory of the player, the price is taken from them and added to the money
-- pool of the vendor, and the stock goes down by one.
-- @param actor [Player the customer]
-- @param vendor [Entity]
-- @param item_id [String]
-- @return [Boolean whether the item has been sold]
function Vendors:buy(actor, vendor, item_id)
  local session = begin_trade(actor, vendor)

  if !session then return false end

  local data = vendor.vendor_data
  local entry = data.sells[item_id]
  local item_table = entry and Item.find_by_id(item_id)

  if !item_table then return false end

  if entry.stock and entry.stock < 1 then
    self:say(vendor, actor, 'no_stock')

    return false
  end

  local currency = data.currency
  local price = self:get_sell_price(vendor, item_id, actor)

  --- Decides whether a player may buy an item from a vendor. Called on the server once the
  -- vendor is known to sell the item and to have it in stock, before the money and the
  -- inventory of the player are checked.
  -- @param actor [Player The customer]
  -- @param vendor [Entity The vendor]
  -- @param item_table [Item The template of the item]
  -- @param price [Number What the player is going to pay]
  -- @return [Boolean Return false to refuse the purchase, String Error phrase to notify
  --   the player with, Map Arguments of that phrase]
  local allowed, reason, arguments = hook.Run('PlayerCanBuyFromVendor', actor, vendor, item_table, price)

  if allowed == false then
    actor:notify(reason or 'error.vendor.cannot_buy', arguments)

    return false
  end

  if !actor:has_money(currency, price) then
    self:say(vendor, actor, 'no_money')

    return false
  end

  local inventory = actor:get_inventories()[actor.default_inventory or 'main_inventory']

  if !inventory then return false end

  local transferable, transfer_error = hook.Run('CanItemTransfer', item_table, inventory)

  if transferable == false then
    actor:notify(transfer_error or 'error.vendor.cannot_buy')

    return false
  end

  local width, height = inventory:get_item_size(item_table)

  if !inventory:find_position(item_table, width, height) then
    actor:notify('error.inventory.no_space')

    return false
  end

  local item_obj = Item.create(item_id)

  if !item_obj then return false end

  local success, error_text = actor:add_item(item_obj, inventory.type)

  if !success then
    Item.remove(item_obj)
    actor:notify(error_text or 'error.inventory.no_space')

    return false
  end

  if price > 0 then
    actor:take_money(currency, price)
  end

  if data.money then
    data.money = self:round_money(currency, math.min(data.money + price, self.max_price))
  end

  if entry.stock then
    entry.stock = entry.stock - 1
  end

  session.traded = true

  actor:notify('notification.vendor.bought', {
    item = item_obj:get_name(),
    price = price,
    currency = Currencies:find_currency(currency).name
  })

  --- Called on the server after a player has bought an item from a vendor: the item is in
  -- their inventory and the money has changed hands.
  -- @param actor [Player The customer]
  -- @param vendor [Entity The vendor]
  -- @param item_obj [Item The new item instance]
  -- @param price [Number What the player has paid]
  hook.Run('PlayerBoughtFromVendor', actor, vendor, item_obj, price)

  self:send_trade_change(vendor, actor, item_id)

  return true
end

--- Buys an item from a player who is trading with a vendor. Refused if the player does not
-- have the item, if the vendor does not take it, if the CanPlayerDropItem or the
-- PlayerCanSellToVendor hook vetoes it, if the money pool of the vendor does not cover the
-- price or if the AdjustReceivedMoney hook refuses the money. The player is paid first, and
-- only then is the item taken out of their inventory and removed; the money pool of the
-- vendor goes down by what the player has received, which the AdjustReceivedMoney hook may
-- have lowered.
-- @param actor [Player the customer]
-- @param vendor [Entity]
-- @param instance_id [Number instance ID of the item]
-- @return [Boolean whether the item has been bought]
-- @see [Vendors#can_buy_item]
function Vendors:sell(actor, vendor, instance_id)
  local session = begin_trade(actor, vendor)

  if !session or !isnumber(instance_id) then return false end

  local has_item, item_obj = actor:has_item_by_id(instance_id)

  if !has_item or !item_obj then return false end

  local inventory = Inventories.find(item_obj.inventory_id)

  if !inventory or inventory.owner != actor then return false end

  local data = vendor.vendor_data
  local currency = data.currency
  local accepted, error_text = self:can_buy_item(vendor, item_obj)

  if !accepted then
    if error_text then
      actor:notify(error_text)
    end

    return false
  end

  if hook.Run('CanPlayerDropItem', actor, item_obj) == false then
    actor:notify('error.vendor.cannot_sell')

    return false
  end

  local price = self:get_buy_price(vendor, item_obj, actor)

  --- Decides whether a player may sell an item to a vendor. Called on the server once the
  -- vendor is known to take the item, before its money pool is checked.
  -- @param actor [Player The customer]
  -- @param vendor [Entity The vendor]
  -- @param item_obj [Item The item instance of the player]
  -- @param price [Number What the player is going to be paid]
  -- @return [Boolean Return false to refuse the sale, String Error phrase to notify the
  --   player with, Map Arguments of that phrase]
  local allowed, reason, arguments = hook.Run('PlayerCanSellToVendor', actor, vendor, item_obj, price)

  if allowed == false then
    actor:notify(reason or 'error.vendor.cannot_sell', arguments)

    return false
  end

  if data.money and data.money < price then
    self:say(vendor, actor, 'broke')

    return false
  end

  local item_name = item_obj:get_name()
  local paid = 0

  if price > 0 then
    paid = actor:give_money(currency, price, vendor)

    if paid == false then
      actor:notify('error.money_refused')

      return false
    end
  end

  hook.Run('PreItemTransfer', item_obj, nil, inventory)

  if !inventory:take_item_by_id(instance_id) then
    if paid > 0 then
      actor:take_money(currency, paid)
    end

    inventory:sync()

    return false
  end

  inventory:sync()

  hook.Run('ItemTransferred', item_obj, nil, inventory)

  Item.remove(item_obj)

  if data.money then
    data.money = self:round_money(currency, math.max(data.money - paid, 0))
  end

  session.traded = true

  actor:notify('notification.vendor.sold', {
    item = item_name,
    price = paid,
    currency = Currencies:find_currency(currency).name
  })

  --- Called on the server after a player has sold an item to a vendor: the item has been
  -- taken from their inventory and removed, and the money has changed hands.
  -- @param actor [Player The customer]
  -- @param vendor [Entity The vendor]
  -- @param item_obj [Item The item instance that was sold; it does not exist anymore]
  -- @param price [Number What the player has been paid, after the AdjustReceivedMoney hook]
  hook.Run('PlayerSoldToVendor', actor, vendor, item_obj, paid)

  self:send_trade_change(vendor, actor)

  return true
end

Cable.receive('fl_vendor_buy', function(actor, vendor, item_id)
  if !isstring(item_id) then return end

  Vendors:buy(actor, vendor, item_id)
end)

Cable.receive('fl_vendor_sell', function(actor, vendor, instance_id)
  if !isnumber(instance_id) then return end

  Vendors:sell(actor, vendor, instance_id)
end)
