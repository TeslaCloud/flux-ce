--- Server side of the Currencies plugin: gives new characters their balances, networks the
-- balances of characters and containers, holds the default rules for giving, dropping and
-- picking up money, and handles the requests of the money panel. Money can only be taken
-- from an entity that has an inventory open for the player who asks: a container, or
-- another player whose inventories are being viewed.

--- Finds an inventory of an entity that is open for a player, which is what entitles the
-- player to take the money of that entity.
-- @param actor [Player the player who wants the money]
-- @param entity [Entity the container or the player that holds the money]
-- @return [Inventory the open inventory, or nil if the entity has none open for the player]
local function find_open_inventory(actor, entity)
  if entity:IsPlayer() then
    for k, v in pairs(entity:get_inventories()) do
      if v:has_receiver(actor) then
        return v
      end
    end
  elseif entity.inventory and entity.inventory:has_receiver(actor) then
    return entity.inventory
  end
end

--- Adds a Currency record with a zero balance for every registered currency to a new
-- character.
-- @param owner [Player]
-- @param char [Character the character being created]
-- @param char_data [Map character creation data]
function Currencies:PostCreateCharacter(owner, char, char_data)
  for k, v in pairs(Currencies.all()) do
    local currency = Currency.new()
      currency.currency_id = k
      currency.amount = 0
    table.insert(char.currencies, currency)
  end
end

--- Networks the currency balances of the newly active character to the player entity.
-- @param owner [Player]
-- @param character [Character]
function Currencies:OnActiveCharacterSet(owner, character)
  local currencies = {}

  if character.currencies then
    for k, v in pairs(character.currencies) do
      currencies[v.currency_id] = v.amount
    end
  end

  owner:set_nv('fl_currencies', currencies)
end

--- Blocks money pickup while the player or the money entity is on its pickup cooldown.
-- @param actor [Player]
-- @param entity [Entity the fl_money entity]
-- @return [Boolean false while on cooldown, otherwise nil]
function Currencies:CanPlayerPickupMoney(actor, entity)
  if actor.next_money_pickup and actor.next_money_pickup > CurTime() then
    return false
  end

  if entity.next_pickup and entity.next_pickup > CurTime() then
    return false
  end
end

--- Gives the contents of a money entity to the player, notifies them and starts their
-- pickup cooldown.
-- @param actor [Player]
-- @param entity [Entity the fl_money entity]
function Currencies:PlayerPickupMoney(actor, entity)
  local currency = entity:get_currency()
  local amount = entity:get_currency_amount()
  local currency_data = Currencies:find_currency(currency)

  actor:give_money(currency, amount)
  actor.next_money_pickup = CurTime() + 0.5
  actor:notify('notification.currency.pickup', { value = amount, currency = currency_data.name }, Color('lightgreen'))
  entity:EmitSound('physics/cardboard/cardboard_box_impact_bullet'..math.random(1, 5)..'.wav', 55)
end

--- Checks that the amount is positive, the currency exists and the player can afford it.
-- @param actor [Player]
-- @param amount [Number]
-- @param currency [String currency ID]
-- @return [Boolean false when not allowed, String error phrase; nothing when allowed]
function Currencies:CanPlayerTransferMoney(actor, amount, currency)
  if !amount or amount <= 0 then
    return false, 'error.invalid_amount'
  end

  local currency_data = Currencies:find_currency(currency)

  if !currency_data then
    return false, 'error.invalid_currency'
  end

  if !actor:has_money(currency, amount) then
    return false, 'error.not_enough_money'
  end
end

--- Checks that the player may transfer the money, that the drop position is within 120
-- units of their eyes and that they are not on pickup cooldown.
-- @param actor [Player]
-- @param amount [Number]
-- @param currency [String currency ID]
-- @param pos [Vector position the money would be dropped at]
-- @param trace [Map eye trace result of the player]
-- @return [Boolean false when not allowed, String error phrase if there is one; nothing
--   when allowed]
function Currencies:CanPlayerDropMoney(actor, amount, currency, pos, trace)
  --- Asks whether an entity may part with an amount of money. Called on the server by the
  -- default handlers of CanPlayerDropMoney and CanGiveMoney, before their own checks.
  -- @param actor [Entity the entity that drops or gives the money: a player, or a container
  --   that money is taken out of]
  -- @param amount [Number]
  -- @param currency [String currency ID]
  -- @return [Boolean return false to refuse, String error phrase for the player]
  local success, err = hook.Run('CanPlayerTransferMoney', actor, amount, currency)

  if success == false then
    return false, err
  end

  if pos:Distance(actor:EyePos()) > 120 then
    return false, 'error.too_far'
  end

  if actor.next_money_pickup and actor.next_money_pickup > CurTime() then
    return false
  end
end

--- Checks that the giver may transfer the money and that the target is valid, able to
-- contain money and within 120 units of the giver's eyes.
-- @param actor [Entity the entity giving the money, normally a player]
-- @param target [Entity the receiver]
-- @param amount [Number]
-- @param currency [String currency ID]
-- @return [Boolean false when not allowed, String error phrase; nothing when allowed]
function Currencies:CanGiveMoney(actor, target, amount, currency)
  local success, err = hook.Run('CanPlayerTransferMoney', actor, amount, currency)

  if success == false then
    return false, err
  end

  if !IsValid(target) then
    return false, 'error.invalid_entity'
  end

  if !hook.Run('CanContainMoney', target) then
    return false, 'error.invalid_entity'
  end

  if IsValid(target) then
    if target:GetPos():Distance(actor:EyePos()) > 120 then
      return false, 'error.too_far'
    end
  end
end

--- Allows players that are not bots to hold money.
-- @param object [Entity]
-- @return [Boolean true for valid non-bot players, otherwise nil]
function Currencies:CanContainMoney(object)
  if IsValid(object) and object:IsPlayer() and !object:IsBot() then
    return true
  end
end

--- Gives a container zero balances for every currency if it has none yet and networks its
-- balances.
-- @param entity [Entity the container]
function Currencies:PreContainerOpen(entity)
  if !entity.currencies then
    local currencies = {}

    for k, v in pairs(Currencies.all()) do
      currencies[k] = 0
    end

    entity.currencies = currencies
  end

  entity:set_nv('fl_currencies', entity.currencies)
end

Cable.receive('fl_currency_give', function(actor, amount, currency, target)
  local success, err = actor:give_money_to(target, currency, amount)

  if success == false then
    actor:notify(err)
  end

  Cable.send(actor, 'fl_rebuild_currency_panel')
end)

Cable.receive('fl_currency_drop', function(actor, amount, currency)
  local success, err = actor:drop_money(currency, amount)

  if success == false then
    actor:notify(err)
  end

  Cable.send(actor, 'fl_rebuild_currency_panel')
end)

Cable.receive('fl_currency_take', function(actor, entity, amount, currency)
  if !IsValid(entity) or entity == actor then return end

  local inventory = find_open_inventory(actor, entity)

  if !inventory then return end

  local success, err = entity:give_money_to(actor, currency, amount)

  if success == false then
    actor:notify(err)
  end

  Cable.send(inventory.receivers, 'fl_rebuild_currency_panel')
end)
