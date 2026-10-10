--- Currencies gives characters and containers money in any number of currencies.
-- A currency is registered with `Currencies:register_currency`. A character gets a `Currency`
-- record with a balance for every registered currency when it is created, and containers hold
-- money as well. Balances are read and changed through the `Entity` extensions, such as
-- `Entity:get_money`, `Entity:give_money` and `Entity:give_money_to`. Players give money to
-- what they are looking at, drop it as an fl_money entity, and move it in and out of
-- containers with the money panel next to their inventory.
--
-- One currency is the default one: the money commands use it when no currency is named, and
-- so can any other plugin, by calling `Currencies:get_default_currency`. It is named by the
-- `default_currency` config; while that config is not set, the only registered currency is
-- the default one.
--
-- A new character starts with the `starting_amount` of every currency, which is 0 unless the
-- currency is registered with another one. The `starting_money` config replaces it for the
-- default currency, and the `GetStartingMoney` hook has the last word.
--
-- Money that lies in the world is kept over restarts while the `save_dropped_money` config is
-- on: it is saved for every map whenever the framework saves its data, and put back when the
-- map is loaded again.
--
-- Hooks decide what is allowed: `CanContainMoney` names the entities that can hold money,
-- `CanPlayerTransferMoney`, `CanGiveMoney`, `CanPlayerDropMoney` and `CanPlayerPickupMoney`
-- can refuse to move it, `PlayerPickupMoney` can refuse a pickup, `AdjustReceivedMoney`
-- changes or refuses the money that an entity is given, `EntityMoneyReceived` reports the
-- money it was given and `EntityMoneyChanged` reports every change of a balance.

local isstring = isstring

PLUGIN:set_global('Currencies')

local stored = Currencies.stored or {}
Currencies.stored = stored

local fallback_model = 'models/props_lab/box01a.mdl'

do
  --- Registers a currency. Characters created afterward get a balance record for it.
  -- ```
  -- Currencies:register_currency('tokens', {
  --   name = 'currency.tokens.name',
  --   symbol = 'T',
  --   decimals = 0,
  --   hidden = false,
  --   -- How much of it a new character starts with.
  --   starting_amount = 100,
  --   -- Model of dropped money, and optionally models for larger amounts.
  --   model = 'models/props_lab/box01a.mdl',
  --   model_table = { [500] = 'models/props_c17/briefcase001a.mdl' }
  -- })
  -- ```
  -- @param id [String currency ID; use lower case, lookups lower-case the ID they are given]
  -- @param data [Map currency definition: name, symbol, decimals, hidden, starting_amount,
  --   model, model_table]
  function Currencies:register_currency(id, data)
    stored[id] = data
  end

  --- Returns every registered currency.
  -- @return [Map currency definitions keyed by currency ID]
  function Currencies:all()
    return stored
  end

  --- Returns the definition of a registered currency.
  -- @param id [String currency ID, letter case is ignored]
  -- @return [Map currency definition, or nil if it is not registered]
  function Currencies:find_currency(id)
    return stored[id:lower()]
  end

  --- Returns the ID of the default currency: the one named by the `default_currency` config
  -- if it is registered, otherwise the only registered currency.
  -- ```
  -- local currency = Currencies:get_default_currency()
  --
  -- if currency and actor:has_money(currency, 50) then
  --   actor:take_money(currency, 50)
  -- end
  -- ```
  -- @return [String currency ID in lower case; nil if the config does not name a registered
  --   currency while none or more than one are registered]
  function Currencies:get_default_currency()
    local id = Config.get('default_currency')
    local lower_id = isstring(id) and id:lower()

    if lower_id and stored[lower_id] then
      return lower_id
    end

    local only = next(stored)

    if only != nil and next(stored, only) == nil then
      return only
    end
  end

  --- Returns the ID of the currency that a player has named, for instance as the argument
  -- of a command, or the ID of the default currency if they have named none or one that is
  -- not registered.
  -- @param id=nil [String currency ID as it was typed, letter case is ignored]
  -- @return [String currency ID in lower case, or nil if the currency is not registered and
  --   there is no default currency either]
  -- @see [Currencies:get_default_currency]
  function Currencies:resolve_currency(id)
    local lower_id = isstring(id) and id:lower()

    if lower_id and stored[lower_id] then
      return lower_id
    end

    return self:get_default_currency()
  end

  --- Returns how much of a currency a new character starts with: the `starting_amount` the
  -- currency is registered with, or the `starting_money` config for the default currency if
  -- that config is above 0. The GetStartingMoney hook may still change the amount for a
  -- particular character.
  -- @param id [String currency ID, letter case is ignored]
  -- @return [Number amount, rounded to the decimals of the currency; 0 if the currency is
  --   not registered]
  function Currencies:get_starting_amount(id)
    local lower_id = isstring(id) and id:lower()
    local currency_data = lower_id and stored[lower_id]

    if !currency_data then
      return 0
    end

    local amount = tonumber(currency_data.starting_amount) or 0
    local override = Config.get('starting_money')

    if isnumber(override) and override > 0 and lower_id == self:get_default_currency() then
      amount = override
    end

    return math.max(0, math.round(amount, currency_data.decimals or 0))
  end

  --- Returns the model that an amount of a currency has while it lies in the world: the
  -- model of the largest threshold in the `model_table` of the currency that the amount
  -- reaches, or else its `model`.
  -- @param id [String currency ID, letter case is ignored]
  -- @param amount [Number]
  -- @return [String model path; a small box if the currency has no model for the amount,
  --   nil if the currency is not registered]
  function Currencies:get_money_model(id, amount)
    local currency_data = isstring(id) and stored[id:lower()]

    if !currency_data then return end

    local model = currency_data.model

    if istable(currency_data.model_table) then
      for k, v in SortedPairs(currency_data.model_table) do
        if k <= amount then
          model = v
        end
      end
    end

    return model or fallback_model
  end
end

require_relative 'cl_hooks'
require_relative 'sv_plugin'
require_relative 'sv_hooks'
