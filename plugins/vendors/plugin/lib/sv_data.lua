--- Settings of vendors: their defaults and the checks that make a table received from a
-- client or read from a save into valid settings.
--
-- The settings of a vendor are a table in the `vendor_data` field of its entity:
-- `name`, `description`, `model` and `animation` (name of the idle sequence, '' to pick one
-- automatically); `currency` (currency ID), `money` (the money pool, false if it is
-- unlimited) and `buy_rate` (percent of the cost of an item that the vendor pays for it);
-- `sells` (item ID to `{ price = Number or false, stock = Number or false }`) and `buys`
-- (item ID to `{ price = Number or false }`), where false stands for the default price and
-- for unlimited stock; `factions` (ID to true, empty to let everyone trade); and `phrases`
-- (phrase ID to text, '' for the default text). Always change the settings with
-- `Vendors:apply`, which checks them. `Vendors.max_price` is the most an item may cost and
-- the most money a vendor may hold, `Vendors.max_stock` the most of an item a vendor may
-- have; the buy-back rate is at most the maximum of the vendors_buy_rate config.

if !Vendors then
  PLUGIN:set_global('Vendors')
end

local pairs = pairs
local istable = istable
local isstring = isstring

Vendors.max_price = 1_000_000_000
Vendors.max_stock = 1_000_000

local text_limits = { name = 64, description = 256, model = 192, animation = 64, phrase = 256 }
local max_ids = 128

--- Makes a clean single-line text out of a value received from a client or read from a save,
-- with `string.clean_line`.
-- @param value [Any]
-- @param limit [Number maximum length in characters]
-- @param fallback=nil [Any what to return if the value is not a string]
-- @return [String the trimmed text without control characters, or the fallback]
local function clean_text(value, limit, fallback)
  if !isstring(value) then return fallback end

  return value:clean_line(limit)
end

--- Returns the highest buy-back rate a vendor may have: the maximum of the vendors_buy_rate
-- config, so that a vendor never pays more for an item than it costs.
-- @return [Number percent]
local function get_max_buy_rate()
  local definition = Config.get_definition('vendors_buy_rate')

  return definition and tonumber(definition.max_value) or 100
end

--- Makes a finite number within a range out of a value received from a client or read from a
-- save.
-- @param value [Any]
-- @param min [Number]
-- @param max [Number]
-- @return [Number the clamped number, or nil if the value is not a finite number]
function Vendors:clean_number(value, min, max)
  value = tonumber(value)

  if !math.is_finite(value) then return end

  return math.Clamp(value, min, max)
end

--- Makes a clean item list out of the one received from a client or read from a save. The
-- list is either a map of item ID to entry or a list of entries with an `id` field. Entries of
-- unknown items and of item bases are dropped.
-- @param entries [Any]
-- @param currency [String currency ID the prices are rounded for]
-- @param with_stock [Boolean whether the entries have a stock]
-- @return [Map item ID to entry]
local function clean_items(entries, currency, with_stock)
  local result = {}

  if !istable(entries) then return result end

  for key, raw_entry in pairs(entries) do
    local id = istable(raw_entry) and isstring(raw_entry.id) and raw_entry.id or key
    local item_table = isstring(id) and Item.find_by_id(id)

    if item_table and !item_table.is_base then
      local entry = istable(raw_entry) and raw_entry or {}
      local price = Vendors:clean_number(entry.price, 0, Vendors.max_price)
      local cleaned = { price = price and Currencies:round(currency, price) or false }

      if with_stock then
        local stock = Vendors:clean_number(entry.stock, 0, Vendors.max_stock)

        cleaned.stock = stock and math.floor(stock) or false
      end

      result[item_table.id] = cleaned
    end
  end

  return result
end

--- Makes a clean set of IDs out of the one received from a client or read from a save. The
-- set is either a map of ID to true or a list of IDs. IDs that are not registered are kept, so
-- that a vendor does not open up to everyone when a faction goes away.
-- @param ids [Any]
-- @return [Map ID to true]
local function clean_ids(ids)
  local result = {}
  local count = 0

  if !istable(ids) then return result end

  for key, value in pairs(ids) do
    local id = isstring(value) and value or (value == true and key)

    if isstring(id) and id != '' and #id <= 64 and !result[id] and count < max_ids then
      result[id] = true
      count += 1
    end
  end

  return result
end

--- Returns the settings of a vendor that has not been set up.
-- @return [Map vendor settings, see the description of this file]
function Vendors:get_default_data()
  local phrases = {}

  for _, phrase in ipairs(self.phrases) do
    phrases[phrase] = ''
  end

  return {
    name = (t'vendor.default_name'),
    description = '',
    model = self.default_model,
    animation = '',
    currency = Currencies:get_default_currency() or '',
    money = false,
    buy_rate = self:clean_number(Config.get('vendors_buy_rate', 50), 0, get_max_buy_rate()) or 50,
    sells = {},
    buys = {},
    factions = {},
    phrases = phrases
  }
end

--- Makes valid vendor settings out of a table that came from a client or from a save. Every
-- field that is missing or not usable is taken from the current settings instead: texts are
-- trimmed and cut, the model has to be an existing .mdl file, the currency has to be
-- registered, numbers have to be finite and are clamped, and unknown items are dropped.
-- @param data [Any the settings to check]
-- @param current=nil [Map settings to fall back to; the defaults if nil]
-- @return [Map vendor settings, a new table]
function Vendors:sanitize(data, current)
  data = istable(data) and data or {}
  current = current or self:get_default_data()

  local result = {}
  local name = clean_text(data.name, text_limits.name)
  local model = clean_text(data.model, text_limits.model)
  local currency = clean_text(data.currency, 64)

  result.name = name and name != '' and name or current.name
  result.description = clean_text(data.description, text_limits.description, current.description)
  result.animation = clean_text(data.animation, text_limits.animation, current.animation)

  if model and model:lower():EndsWith('.mdl')
  and (file.Exists(model, 'GAME') or file.Exists(model:lower(), 'GAME')) then
    result.model = model
  else
    result.model = current.model
  end

  if currency and Currencies:find_currency(currency) then
    result.currency = currency:lower()
  else
    result.currency = current.currency
  end

  if data.money == nil then
    result.money = current.money
  else
    local money = self:clean_number(data.money, 0, self.max_price)

    result.money = money and Currencies:round(result.currency, money) or false
  end

  result.buy_rate = self:clean_number(data.buy_rate, 0, get_max_buy_rate())
    or math.min(current.buy_rate, get_max_buy_rate())
  result.sells = data.sells != nil and clean_items(data.sells, result.currency, true) or current.sells
  result.buys = data.buys != nil and clean_items(data.buys, result.currency, false) or current.buys
  result.factions = data.factions != nil and clean_ids(data.factions) or current.factions
  result.phrases = {}

  for _, phrase in ipairs(self.phrases) do
    local text = istable(data.phrases) and data.phrases[phrase]

    result.phrases[phrase] = clean_text(text, text_limits.phrase, current.phrases[phrase] or '')
  end

  return result
end
