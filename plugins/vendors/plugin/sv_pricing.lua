--- Prices and stock of vendors: what a customer pays for an item a vendor sells, what a
-- vendor pays for an item it buys, which items of a customer a vendor takes, and the data
-- that the trade panel is built from.

--- Runs the AdjustVendorPrice hook on a price and makes the result a valid amount of money.
-- @param actor [Player the customer, or nil]
-- @param vendor [Entity]
-- @param item_obj [Item the item template, or the instance that is being sold to the vendor]
-- @param price [Number the price before adjustments]
-- @param selling [Boolean true if the vendor sells the item, false if it buys it]
-- @return [Number the price, never below 0]
local function adjust_price(actor, vendor, item_obj, price, selling)
  local currency = vendor.vendor_data.currency
  local max_price = Vendors.max_price
  local price_info = {
    price = price,
    base_price = price,
    selling = selling,
    currency = currency
  }

  --- Lets plugins change the price of an item at a vendor. Called on the server whenever a
  -- price is worked out: for every listed item when the trade panel is opened or updated, and
  -- again when an item is bought or sold. Change `price_info.price`; the result is rounded to
  -- the decimals of the currency (down when the vendor is the one who pays) and is never
  -- below 0. Return nothing, so that other handlers get to adjust the price too.
  -- @param actor [Player The customer; nil when a price is asked for without one]
  -- @param vendor [Entity The vendor]
  -- @param item_obj [Item The item: its template when the vendor sells it, the instance of
  --   the customer when the vendor buys it]
  -- @param price_info [Map The price to change in place: `price` (Number), and for reference
  --   `base_price` (Number, the price before any adjustment), `selling` (Boolean, true if the
  --   vendor sells the item and false if it buys it) and `currency` (String currency ID)]
  hook.Run('AdjustVendorPrice', actor, vendor, item_obj, price_info)

  local adjusted = Vendors:clean_number(price_info.price, 0, max_price) or math.Clamp(price, 0, max_price)

  return Vendors:round_money(currency, adjusted, !selling)
end

--- Returns what a customer pays for an item that a vendor sells: the price set for it, or
-- the `cost` of the item, adjusted by the AdjustVendorPrice hook.
-- @param vendor [Entity]
-- @param item_id [String]
-- @param actor=nil [Player the customer]
-- @return [Number the price, or nil if the vendor does not sell the item]
function Vendors:get_sell_price(vendor, item_id, actor)
  local entry = vendor.vendor_data.sells[item_id]
  local item_table = entry and Item.find_by_id(item_id)

  if !item_table then return end

  return adjust_price(actor, vendor, item_table, entry.price or tonumber(item_table.cost) or 0, true)
end

--- Returns what a vendor pays for an item instance: the price set for the item, or the
-- buy-back rate of the vendor applied to the `cost` of the item, scaled down by the share of
-- uses the instance has left and adjusted by the AdjustVendorPrice hook.
-- @param vendor [Entity]
-- @param item_obj [Item the item instance, or a template to get the price of a new item]
-- @param actor=nil [Player the customer]
-- @return [Number the price, or nil if the vendor does not buy the item]
function Vendors:get_buy_price(vendor, item_obj, actor)
  local data = vendor.vendor_data
  local entry = data.buys[item_obj.id]

  if !entry then return end

  local price = entry.price or (tonumber(item_obj.cost) or 0) * data.buy_rate / 100
  local max_uses = tonumber(item_obj.max_uses)

  if max_uses and max_uses > 1 and isnumber(item_obj.uses) then
    price = price * math.Clamp(item_obj.uses / max_uses, 0, 1)
  end

  return adjust_price(actor, vendor, item_obj, price, false)
end

--- Checks whether a vendor would take an item instance: the vendor has to buy items of that
-- kind, the item must not be equipped and, if it holds other items, has to be empty.
-- @param vendor [Entity]
-- @param item_obj [Item the item instance]
-- @return [Boolean, String error phrase if the item is one the vendor buys but cannot take]
function Vendors:can_buy_item(vendor, item_obj)
  if !vendor.vendor_data.buys[item_obj.id] then
    return false
  end

  if item_obj.is_equipped and item_obj:is_equipped() then
    return false, 'error.vendor.equipped'
  end

  if item_obj.inventory then
    if !item_obj.inventory:is_empty() then
      return false, 'error.vendor.not_empty'
    end
  elseif istable(item_obj.items) and !table.IsEmpty(item_obj.items) then
    return false, 'error.vendor.not_empty'
  end

  return true
end

--- Returns the items of a player that a vendor would take from them.
-- @param vendor [Entity]
-- @param actor [Player]
-- @return [List<Item> item instances]
-- @see [Vendors#can_buy_item]
function Vendors:get_sellable_items(vendor, actor)
  local items = {}

  if table.IsEmpty(vendor.vendor_data.buys) then return items end

  for inv_type, inventory in pairs(actor:get_inventories()) do
    for k, instance_id in ipairs(inventory:get_items_ids()) do
      local item_obj = Item.find_instance_by_id(instance_id)

      if item_obj and self:can_buy_item(vendor, item_obj) then
        table.insert(items, item_obj)
      end
    end
  end

  return items
end

--- Builds what the trade panel of a customer shows: `name`, `description`, `currency` and
-- `money` of the vendor, `sells` (a list of `{ id, price, stock }`, one entry for every item
-- the vendor sells) and `buys` (a list of `{ instance_id, price }`, one entry for every item
-- of the customer that the vendor takes).
-- @param vendor [Entity]
-- @param actor [Player the customer]
-- @return [Map]
function Vendors:get_trade_data(vendor, actor)
  local data = vendor.vendor_data
  local sells = {}
  local buys = {}

  for id, entry in SortedPairs(data.sells) do
    local price = self:get_sell_price(vendor, id, actor)

    if price then
      table.insert(sells, { id = id, price = price, stock = entry.stock })
    end
  end

  for k, item_obj in ipairs(self:get_sellable_items(vendor, actor)) do
    table.insert(buys, {
      instance_id = item_obj.instance_id,
      price = self:get_buy_price(vendor, item_obj, actor)
    })
  end

  return {
    name = data.name,
    description = data.description,
    currency = data.currency,
    money = data.money,
    sells = sells,
    buys = buys
  }
end
