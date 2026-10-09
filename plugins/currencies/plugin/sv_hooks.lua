--- Server side of the Currencies plugin: gives new characters their balances, networks the
-- balances of characters and containers, holds the default rules for giving, dropping and
-- picking up money, saves and loads the money that lies in the world, and handles the
-- requests of the money panel. Money can only be taken from an entity that has an inventory
-- open for the player who asks: a container, or another player whose inventories are being
-- viewed.

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

--- Adds a Currency record for every registered currency to a new character, with the
-- starting amount of that currency as its balance. Runs the GetStartingMoney hook for every
-- currency.
-- @param owner [Player]
-- @param char [Character the character being created]
-- @param char_data [Map character creation data]
function Currencies:PostCreateCharacter(owner, char, char_data)
  for k, v in pairs(Currencies.all()) do
    local amount = self:get_starting_amount(k)

    --- Lets plugins decide how much of a currency a new character starts with, for instance
    -- by its faction. Called on the server for every registered currency while a character
    -- is being created, before it is saved.
    -- @param owner [Player the player the character is created for]
    -- @param char [Character the new character, not saved yet]
    -- @param currency [String currency ID]
    -- @param amount [Number what the character would start with, see
    --   `Currencies:get_starting_amount`]
    -- @param char_data [Map creation data the character was built from]
    -- @return [Number return the amount the character should start with; it is rounded to
    --   the decimals of the currency and never below 0. Return nothing to keep the amount]
    local result = hook.Run('GetStartingMoney', owner, char, k, amount, char_data)

    if isnumber(result) and result == result and result != math.huge then
      amount = math.max(0, math.round(result, v.decimals or 0))
    end

    local currency = Currency.new()
      currency.currency_id = k
      currency.amount = amount
    table.insert(char.currencies, currency)
  end
end

--- Puts the saved money back into the world when the framework loads its data, if the
-- save_dropped_money config is on.
function Currencies:LoadData()
  if Config.get('save_dropped_money') then
    self:load_money()
  end
end

--- Saves the money that lies in the world when the framework saves its data, if the
-- save_dropped_money config is on. Deletes what has been saved for the map otherwise, so
-- that money which is long gone does not come back once the config is turned on again.
function Currencies:SaveData()
  if Config.get('save_dropped_money') then
    self:save_money()
  else
    Data.delete_plugin('money')
  end

  self.money_dirty = nil
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

--- Checks that the amount is a positive, finite number with no more decimals than the
-- currency has (a whole number for a currency without decimals), that the currency exists
-- and that the entity can afford it. An amount with too many decimals is refused rather
-- than rounded, so that both sides of a transfer always change by exactly the same sum.
-- @param actor [Entity the entity that parts with the money, a player or a container]
-- @param amount [Number]
-- @param currency [String currency ID]
-- @return [Boolean false when not allowed, String error phrase; nothing when allowed]
function Currencies:CanPlayerTransferMoney(actor, amount, currency)
  if !isnumber(amount) or amount != amount or amount <= 0 or amount == math.huge then
    return false, 'error.invalid_amount'
  end

  local currency_data = isstring(currency) and Currencies:find_currency(currency)

  if !currency_data then
    return false, 'error.invalid_currency'
  end

  if math.round(amount, currency_data.decimals or 0) != amount then
    return false, 'error.invalid_amount'
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
  -- default handlers of CanPlayerDropMoney and CanGiveMoney, before their own checks. The
  -- handler of the Currencies plugin refuses amounts that are not positive, finite numbers
  -- with at most as many decimals as the currency has, unknown currencies and amounts the
  -- entity cannot afford.
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
