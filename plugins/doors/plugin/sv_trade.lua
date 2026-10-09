--- Buying and selling of ownable doors, serverside.
-- `Doors:buy` and `Doors:sell` are what the door menu of a player asks for: they check the
-- rules, ask the PlayerCanBuyDoor and PlayerCanSellDoor hooks, move the money through the
-- Currencies plugin and save the doors. `Doors:get_refund` is what the owner gets back for a
-- sale, the door_sell_share percent of what was paid.

--- Returns what the owner of a door gets back for selling it: the door_sell_share percent
-- of what the door was bought for.
-- @param entity [Entity the door]
-- @return [Number the refund, 0 if there is none, String ID of the currency of the refund,
--   nil if there is none]
function Doors:get_refund(entity)
  local owner = self:get_owner(entity)

  if !owner or !Currencies or !isstring(owner.currency) then return 0 end

  local currency_data = Currencies:find_currency(owner.currency)

  if !currency_data then return 0 end

  local share = math.Clamp(tonumber(Config.get('door_sell_share')) or 0, 0, 100)
  local refund = math.round((tonumber(owner.paid) or 0) * share / 100, currency_data.decimals or 0)

  if refund <= 0 then return 0 end

  return refund, owner.currency
end

--- Makes the active character of a player buy a door and the doors linked with it: checks
-- that the door is for sale, the door limit of the character and their money, asks the
-- PlayerCanBuyDoor hook, takes the price and makes the character the owner. The player is
-- told about a purchase; a refusal is returned for the caller to tell.
-- ```
-- local success, reason, arguments = Doors:buy(actor, entity)
--
-- if !success then
--   actor:notify(reason, arguments)
-- end
-- ```
-- @param actor [Player]
-- @param entity [Entity the door]
-- @return [Boolean whether the door was bought, String error phrase if it was not, Map
--   arguments of the phrase]
function Doors:buy(actor, entity)
  local root = self:get_root(entity)
  local state = self:get_state(root)

  if !state.ownable then return false, 'error.door.not_ownable' end
  if state.owner then return false, 'error.door.already_owned' end

  local character_id = self:get_character_id(actor)

  if !character_id then return false, 'error.cant_now' end

  local limit = tonumber(Config.get('door_limit')) or 0

  if limit > 0 and self:count_owned(character_id) >= limit then
    return false, 'error.door.limit', { limit = limit }
  end

  local price, currency = self:get_price(root)
  local currency_data = currency and Currencies:find_currency(currency)

  if price > 0 and !actor:has_money(currency, price) then
    return false, 'error.door.cant_afford', { value = price, currency = currency_data.name }
  end

  --- Asks whether a player may buy a door. Called on the server once the door is known to
  -- be for sale, the character to be under its door limit and the player to have the
  -- money, before anything is taken.
  -- @param actor [Player]
  -- @param entity [Entity the door, or the main door of its group]
  -- @param price [Number what the player is about to pay, 0 if the door is free]
  -- @param currency [String ID of the currency of the price, nil if there is none]
  -- @return [Boolean return false to refuse the purchase, String error phrase to show the
  --   player, Map arguments of the phrase]
  local allowed, reason, arguments = hook.Run('PlayerCanBuyDoor', actor, root, price, currency)

  if allowed == false then
    return false, reason or 'error.door.cannot_buy', arguments
  end

  if price > 0 then
    actor:take_money(currency, price)
  end

  self:set_owner(root, character_id, actor:name(true), price, price > 0 and currency or nil)

  if price > 0 then
    actor:notify('notification.door.bought', { value = price, currency = currency_data.name }, Color('lightgreen'))
  else
    actor:notify('notification.door.taken', nil, Color('lightgreen'))
  end

  self:save()

  return true
end

--- Makes a player sell a door that their active character owns, together with the doors
-- linked with it: asks the PlayerCanSellDoor hook, pays the refund and releases the door.
-- Nothing changes if the AdjustReceivedMoney hook refuses the refund. The player is told
-- about a sale, with the refund they have actually received; a refusal is returned for the
-- caller to tell.
-- @param actor [Player]
-- @param entity [Entity the door]
-- @return [Boolean whether the door was sold, String error phrase if it was not, Map
--   arguments of the phrase]
function Doors:sell(actor, entity)
  local root = self:get_root(entity)

  if self:get_access_level(actor, root) < DOOR_ACCESS_OWNER then
    return false, 'error.door.not_owner'
  end

  local refund, currency = self:get_refund(root)

  --- Asks whether a player may sell a door that their character owns. Called on the
  -- server before the door is released.
  -- @param actor [Player]
  -- @param entity [Entity the door, or the main door of its group]
  -- @param refund [Number what the player is about to get back, 0 if nothing]
  -- @param currency [String ID of the currency of the refund, nil if there is none]
  -- @return [Boolean return false to refuse the sale, String error phrase to show the
  --   player, Map arguments of the phrase]
  local allowed, reason, arguments = hook.Run('PlayerCanSellDoor', actor, root, refund, currency)

  if allowed == false then
    return false, reason or 'error.door.cannot_sell', arguments
  end

  local received = 0

  if refund > 0 then
    received = actor:give_money(currency, refund, 'door_sale')

    if received == false then
      return false, 'error.money_refused'
    end
  end

  self:clear_owner(root)

  if received > 0 then
    local currency_data = Currencies:find_currency(currency)

    actor:notify('notification.door.sold', { value = received, currency = currency_data.name }, Color('lightgreen'))
  else
    actor:notify('notification.door.abandoned')
  end

  self:save()

  return true
end
