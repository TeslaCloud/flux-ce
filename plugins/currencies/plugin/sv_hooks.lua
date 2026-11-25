--- Server-side hooks of the Currencies plugin: they load the balances together with the
-- characters, give new characters their balances, network the balances of characters and
-- containers, hold the default rules for giving, dropping and picking up money, save and
-- load the money that lies in the world and drop the money of a container whose items are
-- dropped when it is removed.

local IsValid = IsValid
local CurTime = CurTime
local pairs = pairs

local reach_sqr = 120 * 120

--- Loads the balances of characters together with them.
-- @param preloads [Map relations of the characters, changed in place]
function Currencies:AdjustCharacterPreloads(preloads)
  preloads[#preloads + 1] = 'currencies'
end

--- Adds a Currency record for every registered currency to a new character, with the
-- starting amount of that currency as its balance. Runs the GetStartingMoney hook for every
-- currency.
-- @param owner [Player]
-- @param char [Character the character being created]
-- @param char_data [Map character creation data]
function Currencies:PostCreateCharacter(owner, char, char_data)
  for currency_id in pairs(Currencies.all()) do
    local amount = self:get_starting_amount(currency_id)

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
    local result = hook.Run('GetStartingMoney', owner, char, currency_id, amount, char_data)

    if math.is_finite(result) then
      amount = math.max(0, self:round(currency_id, result))
    end

    local currency = Currency.new()
      currency.currency_id = currency_id
      currency.amount = amount
    table.insert(char.currencies, currency)
  end
end

--- Puts the saved money back into the world when the framework loads its data, if the
-- currencies_save_dropped_money config is on.
function Currencies:LoadData()
  if Config.get('currencies_save_dropped_money') then
    self:load_money()
  end
end

--- Saves the money that lies in the world when the framework saves its data, if the
-- currencies_save_dropped_money config is on. Deletes what has been saved for the map otherwise, so
-- that money which is long gone does not come back once the config is turned on again.
function Currencies:SaveData()
  if Config.get('currencies_save_dropped_money') then
    self:save_money()
  else
    Data.delete_plugin('money')
  end

  self.money_dirty = nil
end

--- Networks the currency balances of the newly active character to the player, and to
-- nobody else.
-- @param owner [Player]
-- @param character [Character]
function Currencies:ActiveCharacterSet(owner, character)
  local currencies = {}

  if character.currencies then
    for _, currency in pairs(character.currencies) do
      currencies[currency.currency_id] = currency.amount
    end
  end

  owner:set_private_nv('fl_currencies', currencies)
end

--- Clears the networked currency balances of a player who drops their character.
-- @param owner [Player]
-- @param _character [Character the character that is being dropped]
function Currencies:ActiveCharacterCleared(owner, _character)
  owner:set_private_nv('fl_currencies', {})
end

--- Stops sending the balances of a player to someone who has closed the inventories of
-- that player.
-- @param _actor [Player the player who has closed the inventory]
-- @param inventory [Inventory]
function Currencies:InventoryClosed(_actor, inventory)
  local owner = inventory.owner

  if IsValid(owner) and owner:IsPlayer() then
    self:update_balance_recipients(owner)
  end
end

--- Blocks money pickup while the player or the money entity is on its pickup cooldown.
-- @param actor [Player]
-- @param entity [Entity the fl_money entity]
-- @return [Boolean false while on cooldown, otherwise nil]
function Currencies:PlayerCanPickupMoney(actor, entity)
  local cur_time = CurTime()

  if actor.next_money_pickup and actor.next_money_pickup > cur_time then
    return false
  end

  if entity.next_pickup and entity.next_pickup > cur_time then
    return false
  end
end

--- Checks that the drop position is within 120 units of the player's eyes and that they
-- are neither on pickup cooldown nor have dropped money less than half a second ago.
-- @param actor [Player]
-- @param _amount [Number]
-- @param _currency [String currency ID]
-- @param pos [Vector position the money would be dropped at]
-- @param _trace [Map eye trace result of the player]
-- @return [Boolean false when not allowed, String error phrase; nothing when allowed]
function Currencies:PlayerCanDropMoney(actor, _amount, _currency, pos, _trace)
  if pos:DistToSqr(actor:EyePos()) > reach_sqr then
    return false, 'error.too_far'
  end

  local cur_time = CurTime()

  if actor.next_money_pickup and actor.next_money_pickup > cur_time then
    return false, 'error.wait'
  end

  if actor.next_money_drop and actor.next_money_drop > cur_time then
    return false, 'error.wait'
  end
end

--- Checks that the target is able to contain money and is within 120 units of the giver's
-- eyes.
-- @param actor [Entity the entity giving the money, normally a player]
-- @param target [Entity the receiver]
-- @param _amount [Number]
-- @param _currency [String currency ID]
-- @return [Boolean false when not allowed, String error phrase; nothing when allowed]
function Currencies:CanEntityGiveMoney(actor, target, _amount, _currency)
  if !hook.Run('CanEntityContainMoney', target) then
    return false, 'error.invalid_entity'
  end

  if target:GetPos():DistToSqr(actor:EyePos()) > reach_sqr then
    return false, 'error.too_far'
  end
end

--- Allows players that are not bots and have a character loaded to hold money.
-- @param object [Entity]
-- @return [Boolean true for valid non-bot players with a loaded character, otherwise nil]
function Currencies:CanEntityContainMoney(object)
  if IsValid(object) and object:IsPlayer() and !object:IsBot() and object:is_character_loaded() then
    return true
  end
end

--- Gives a container zero balances for every currency if it has none yet and networks its
-- balances.
-- @param entity [Entity the container]
function Currencies:PreOpenContainer(entity)
  if !entity.currencies then
    local currencies = {}

    for currency_id in pairs(Currencies.all()) do
      currencies[currency_id] = 0
    end

    entity.currencies = currencies
  end

  entity:set_nv('fl_currencies', entity.currencies)
end

--- Drops the money of a removed container next to where it was, when its items are dropped
-- as well; otherwise the money goes with the container, as its items do. The money is
-- dropped on the next tick, with the items.
-- @param entity [Entity the container prop that is being removed]
-- @param spilled [Boolean true if the items of the container are dropped on the ground]
function Currencies:ContainerRemoved(entity, spilled)
  local balances = entity.currencies

  if !spilled or !istable(balances) then return end

  local origin = entity:WorldSpaceCenter()

  timer.Simple(0, function()
    local dropped = false

    for currency_id, amount in pairs(balances) do
      if isnumber(amount) and amount > 0 and IsValid(self:spawn_money(currency_id, amount, origin)) then
        dropped = true
      end
    end

    if dropped then
      self:queue_money_save()
    end
  end)
end
