--- Server side of the Vendors plugin: creates, edits, removes, saves and loads vendors, works
-- out prices, keeps track of who is trading with which vendor and carries out purchases and
-- sales.
--
-- The settings of a vendor are a table in the `vendor_data` field of its entity:
-- `name`, `description`, `model` and `animation` (name of the idle sequence, '' to pick one
-- automatically); `currency` (currency ID), `money` (the money pool, false if it is
-- unlimited) and `buy_rate` (percent of the cost of an item that the vendor pays for it);
-- `sells` (item ID to `{ price = Number or false, stock = Number or false }`) and `buys`
-- (item ID to `{ price = Number or false }`), where false stands for the default price and
-- for unlimited stock; `factions` (ID to true, empty to let everyone trade); and `phrases`
-- (phrase ID to text, '' for the default text). Always change the settings with
-- `Vendors:apply`, which checks them.
--
-- A player who is trading has a session in `Vendors.sessions`, a table with the `vendor`
-- and the `traded` flag, from `Vendors:open` until `Vendors:close`.

local sessions = Vendors.sessions or {}
Vendors.sessions = sessions

local text_limits = { name = 64, description = 256, model = 192, animation = 64, phrase = 256 }
local max_price = 1000000000
local max_stock = 1000000
local max_ids = 128
local trade_interval = 0.2
local use_interval = 1

--- Cuts a text to a number of characters, or to that many bytes if it is not valid UTF-8.
-- @param text [String]
-- @param limit [Number]
-- @return [String]
local function limit_text(text, limit)
  if #text <= limit then return text end

  local length = utf8.len(text)

  if length and length <= limit then return text end

  local success, cut = pcall(string.utf8sub, text, 1, limit)

  return success and cut or text:sub(1, limit)
end

--- Makes a clean single-line text out of a value received from a client or read from a save.
-- @param value [Any]
-- @param limit [Number maximum length in characters]
-- @param fallback=nil [Any what to return if the value is not a string]
-- @return [String the trimmed text without control characters, or the fallback]
local function clean_text(value, limit, fallback)
  if !isstring(value) then return fallback end

  value = value:gsub('%c', ' ')

  return limit_text(value:Trim(), limit)
end

--- Makes a finite number within a range out of a value received from a client or read from a
-- save.
-- @param value [Any]
-- @param min [Number]
-- @param max [Number]
-- @return [Number the clamped number, or nil if the value is not a finite number]
local function clean_number(value, min, max)
  value = tonumber(value)

  if !value or value != value or value == math.huge or value == -math.huge then return end

  return math.Clamp(value, min, max)
end

--- Rounds an amount of money to the decimals of a currency.
-- @param currency [String currency ID]
-- @param amount [Number]
-- @param down=false [Boolean round down instead of to the nearest value]
-- @return [Number]
local function round_money(currency, amount, down)
  local currency_data = isstring(currency) and Currencies:find_currency(currency)
  local decimals = currency_data and currency_data.decimals or 0

  if down then
    local factor = 10 ^ decimals

    return math.floor(amount * factor + 0.000001) / factor
  end

  return math.Round(amount, decimals)
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

  for k, v in pairs(entries) do
    local id = istable(v) and isstring(v.id) and v.id or k
    local item_table = isstring(id) and Item.find_by_id(id)

    if item_table and !item_table.is_base then
      local entry = istable(v) and v or {}
      local price = clean_number(entry.price, 0, max_price)
      local cleaned = { price = price and round_money(currency, price) or false }

      if with_stock then
        local stock = clean_number(entry.stock, 0, max_stock)

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

  for k, v in pairs(ids) do
    local id = isstring(v) and v or (v == true and k)

    if isstring(id) and id != '' and #id <= 64 and !result[id] and count < max_ids then
      result[id] = true
      count = count + 1
    end
  end

  return result
end

--- Turns a map of item ID to entry into a list of entries with an `id` field, which survives
-- being saved as JSON whatever the IDs look like.
-- @param items [Map item ID to entry]
-- @return [List<Map>]
local function items_to_list(items)
  local entries = {}

  for id, entry in SortedPairs(items) do
    table.insert(entries, { id = id, price = entry.price, stock = entry.stock })
  end

  return entries
end

--- Runs the AdjustVendorPrice hook on a price and makes the result a valid amount of money.
-- @param actor [Player the customer, or nil]
-- @param vendor [Entity]
-- @param item_obj [Item the item template, or the instance that is being sold to the vendor]
-- @param price [Number the price before adjustments]
-- @param selling [Boolean true if the vendor sells the item, false if it buys it]
-- @return [Number the price, never below 0]
local function adjust_price(actor, vendor, item_obj, price, selling)
  local currency = vendor.vendor_data.currency
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

  local adjusted = clean_number(price_info.price, 0, max_price) or math.Clamp(price, 0, max_price)

  return round_money(currency, adjusted, !selling)
end

--- Returns the settings of a vendor that has not been set up.
-- @return [Map vendor settings, see the description of this file]
function Vendors:get_default_data()
  local phrases = {}

  for k, v in ipairs(self.phrases) do
    phrases[v] = ''
  end

  return {
    name = (t'vendor.default_name'),
    description = '',
    model = self.default_model,
    animation = '',
    currency = Currencies:get_default_currency() or '',
    money = false,
    buy_rate = clean_number(Config.get('vendor_buy_rate', 50), 0, 1000) or 50,
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
    local money = clean_number(data.money, 0, max_price)

    result.money = money and round_money(result.currency, money) or false
  end

  result.buy_rate = clean_number(data.buy_rate, 0, 1000) or current.buy_rate
  result.sells = data.sells != nil and clean_items(data.sells, result.currency, true) or current.sells
  result.buys = data.buys != nil and clean_items(data.buys, result.currency, false) or current.buys
  result.factions = data.factions != nil and clean_ids(data.factions) or current.factions
  result.phrases = {}

  for k, v in ipairs(self.phrases) do
    local text = istable(data.phrases) and data.phrases[v]

    result.phrases[v] = clean_text(text, text_limits.phrase, current.phrases[v] or '')
  end

  return result
end

--- Creates a vendor.
-- ```
-- local vendor = Vendors:create(trace.HitPos, Angle(0, 90, 0), {
--   name = 'Grocer',
--   sells = { canned_food = { price = 15, stock = 20 } },
--   buys = { canned_food = { price = false } }
-- })
--
-- Vendors:save()
-- ```
-- @param position [Vector where the vendor stands]
-- @param angles=Angle(0, 0, 0) [Angle]
-- @param data=nil [Map vendor settings; whatever is left out gets its default]
-- @return [Entity the vendor, or nil if the entity could not be created]
-- @see [Vendors#sanitize]
function Vendors:create(position, angles, data)
  local vendor = ents.Create(self.entity_class)

  if !IsValid(vendor) then return end

  data = self:sanitize(data)

  vendor.vendor_data = data
  vendor:SetModel(data.model)
  vendor:SetPos(position)
  vendor:SetAngles(angles or Angle(0, 0, 0))
  vendor:Spawn()
  vendor:set_vendor_data(data)

  return vendor
end

--- Changes the settings of a vendor and sends the new prices and stock to its customers.
-- @param vendor [Entity]
-- @param data [Map the settings to change; whatever is left out stays as it is]
-- @return [Map the settings of the vendor after the change, or nil if it is not a vendor]
-- @see [Vendors#sanitize]
function Vendors:apply(vendor, data)
  if !self:is_vendor(vendor) then return end

  data = self:sanitize(data, vendor.vendor_data)

  vendor:set_vendor_data(data)

  self:update_customers(vendor)

  return data
end

--- Moves a vendor to another spot. Its customers stop trading once they are out of reach.
-- Call `Vendors:save` afterwards to make the move last.
-- @param vendor [Entity]
-- @param position [Vector where the vendor is going to stand]
-- @param angles=nil [Angle new angles; the vendor keeps its own if nil]
-- @return [Boolean false if it is not a vendor]
function Vendors:move(vendor, position, angles)
  if !self:is_vendor(vendor) then return false end

  vendor:SetPos(position)

  if angles then
    vendor:SetAngles(angles)
  end

  vendor:setup_physics()

  return true
end

--- Removes a vendor from the map and closes the trade panel of its customers. Call
-- `Vendors:save` afterwards to make the removal last.
-- @param vendor [Entity]
-- @return [Boolean false if it is not a vendor]
function Vendors:remove(vendor)
  if !self:is_vendor(vendor) then return false end

  for k, v in ipairs(self:get_customers(vendor)) do
    self:close(v, false, true)
  end

  vendor:Remove()

  return true
end

--- Builds the table that a vendor is saved as: its settings with the item lists and the ID
-- sets turned into lists, plus its position and angles.
-- @param vendor [Entity]
-- @return [Map]
function Vendors:to_saveable(vendor)
  local data = vendor.vendor_data

  return {
    position = vendor:GetPos(),
    angles = vendor:GetAngles(),
    name = data.name,
    description = data.description,
    model = data.model,
    animation = data.animation,
    currency = data.currency,
    money = data.money,
    buy_rate = data.buy_rate,
    sells = items_to_list(data.sells),
    buys = items_to_list(data.buys),
    factions = table.GetKeys(data.factions),
    phrases = data.phrases
  }
end

--- Writes every vendor of the map to the plugin data storage.
function Vendors:save()
  local vendors = {}

  for k, v in ipairs(ents.FindByClass(self.entity_class)) do
    if v.vendor_data and !v:IsMarkedForDeletion() then
      table.insert(vendors, self:to_saveable(v))
    end
  end

  Data.save_plugin('vendors', vendors)
end

--- Removes the vendors that are on the map and spawns the saved ones.
function Vendors:load()
  for k, v in ipairs(ents.FindByClass(self.entity_class)) do
    self:remove(v)
  end

  local saved = Data.load_plugin('vendors', {})

  if !istable(saved) then return end

  for k, v in pairs(saved) do
    if istable(v) and isvector(v.position) and isangle(v.angles) then
      self:create(v.position, v.angles, v)
    end
  end
end

--- Opens the vendor editor for a player who has the 'manage_vendors' permission. The vendor
-- is sent as an entity index, because a vendor that has just been created does not exist
-- on the client yet.
-- @param actor [Player]
-- @param vendor [Entity]
-- @return [Boolean whether the editor has been opened]
function Vendors:edit(actor, vendor)
  if !IsValid(actor) or !self:is_vendor(vendor) or !actor:can('manage_vendors') then return false end

  Cable.send(actor, 'fl_vendor_edit', vendor:EntIndex(), vendor.vendor_data)

  return true
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

--- Makes a vendor say one of its phrases to a player: the text set for the vendor, or the
-- default phrase in the language of the player. The line goes to the chat of that player
-- only, or into a notification if the Chatbox plugin is not loaded. While the 'vendor_talk'
-- config is off vendors do not talk: the greeting and the thanks are left out, and the
-- phrases that explain why a trade did not happen are shown as plain notifications with
-- their default text.
-- @param vendor [Entity]
-- @param actor [Player who the vendor talks to]
-- @param id [String phrase ID, one of `Vendors.phrases`]
function Vendors:say(vendor, actor, id)
  if !IsValid(actor) or !self:is_vendor(vendor) then return end

  if Config.get('vendor_talk', true) == false then
    if id != 'greeting' and id != 'thanks' then
      actor:notify('vendor.phrase.'..id)
    end

    return
  end

  local data = vendor.vendor_data
  local lang = Flux.Lang:get_player_lang(actor)
  local text = data.phrases[id]

  if !isstring(text) or text == '' then
    text = (t('vendor.phrase.'..id, nil, lang))
  end

  local message = {
    name = data.name,
    text = text,
    color = Color(255, 255, 160)
  }

  --- Called on the server before a vendor says one of its phrases to a player. Change the
  -- fields of `message` to alter the line.
  -- @param vendor [Entity The vendor]
  -- @param actor [Player The player the vendor talks to]
  -- @param id [String Phrase ID: 'greeting', 'refuse', 'no_money', 'no_stock', 'broke' or
  --   'thanks']
  -- @param message [Map The line to change in place: `name` (String, who speaks), `text`
  --   (String, what is said) and `color` (Color of the line in the chat)]
  -- @return [Boolean Return false to keep the vendor silent]
  if hook.Run('VendorSay', vendor, actor, id, message) == false then return end

  if !isstring(message.text) or message.text == '' then return end

  local line = tostring(message.name)..' '..(t('vendor.says', nil, lang))..': "'..message.text..'"'

  if Chatbox then
    Chatbox.add_text(actor, IsColor(message.color) and message.color or color_white, line)
  else
    actor:notify(line)
  end
end

--- Checks whether a player may trade with a vendor. The PlayerCanUseVendor hook decides
-- first; if it has no opinion, the player needs one of the factions of the vendor, unless
-- the vendor has none. A schema that restricts vendors further does so through the hook.
-- @param actor [Player]
-- @param vendor [Entity]
-- @return [Boolean, String error phrase given by the hook, Map arguments of the phrase]
function Vendors:can_trade(actor, vendor)
  --- Decides whether a player may trade with a vendor. Called on the server when a player
  -- uses a vendor and again before every purchase and sale.
  -- @param actor [Player The customer]
  -- @param vendor [Entity The vendor]
  -- @return [Boolean Return false to refuse the player and true to let them trade whatever
  --   the factions of the vendor are; nothing leaves it to those, String Error phrase to
  --   notify a refused player with instead of the 'refuse' phrase of the vendor, Map
  --   Arguments of that phrase]
  local allowed, reason, arguments = hook.Run('PlayerCanUseVendor', actor, vendor)

  if allowed == false then
    return false, reason, arguments
  end

  if allowed == true then
    return true
  end

  local factions = vendor.vendor_data.factions

  if Factions and !table.IsEmpty(factions) then
    return factions[actor:get_faction_id()] == true
  end

  return true
end

--- Returns the players who have the trade panel of a vendor open.
-- @param vendor [Entity]
-- @return [List<Player>]
function Vendors:get_customers(vendor)
  local customers = {}

  for actor, session in pairs(sessions) do
    if session.vendor == vendor and IsValid(actor) then
      table.insert(customers, actor)
    end
  end

  return customers
end

--- Returns the vendor a player is trading with.
-- @param actor [Player]
-- @return [Entity the vendor, or nil if the player is not trading]
function Vendors:get_vendor(actor)
  local session = sessions[actor]

  return session and session.vendor
end

--- Sends what the trade panel shows to the customers of a vendor again.
-- @param vendor [Entity]
-- @param actor=nil [Player the only customer to send it to; all of them if nil]
function Vendors:update_customers(vendor, actor)
  for k, v in ipairs(self:get_customers(vendor)) do
    if !actor or actor == v then
      Cable.send(v, 'fl_vendor_update', vendor, self:get_trade_data(vendor, v))
    end
  end
end

--- Tells the customers of a vendor what a trade has changed: the customer who traded gets
-- the whole trade panel again, because their items have changed, and every other customer
-- gets just the money pool of the vendor and the stock of the item that was traded.
-- @param vendor [Entity]
-- @param actor [Player the customer who has traded]
-- @param item_id=nil [String ID of the item whose stock has changed, nil if none has]
function Vendors:send_trade_change(vendor, actor, item_id)
  local data = vendor.vendor_data
  local entry = item_id and data.sells[item_id]
  local stock = entry and entry.stock or nil
  local others = {}

  for k, v in ipairs(self:get_customers(vendor)) do
    if v != actor then
      table.insert(others, v)
    end
  end

  self:update_customers(vendor, actor)

  if #others > 0 then
    Cable.send(others, 'fl_vendor_change', vendor, data.money, item_id, stock)
  end
end

--- Starts trading: checks that the player is alive, has a character that can hold money, is
-- within reach of the vendor and may trade with it, opens the trade panel and makes the
-- vendor greet the player.
-- A player who may not trade hears the 'refuse' phrase of the vendor instead.
-- @param actor [Player]
-- @param vendor [Entity]
-- @return [Boolean whether the trade panel has been opened]
-- @see [Vendors#can_trade]
function Vendors:open(actor, vendor)
  if !IsValid(actor) or !actor:IsPlayer() or !self:is_vendor(vendor) then return false end
  if !actor:Alive() or !actor:is_character_loaded() or !actor:can_contain_money() then return false end
  if !Inventories.is_in_reach(actor, vendor) then return false end

  local cur_time = CurTime()

  if actor.next_vendor_use and actor.next_vendor_use > cur_time then return false end

  actor.next_vendor_use = cur_time + use_interval

  local allowed, reason, arguments = self:can_trade(actor, vendor)

  if !allowed then
    if reason then
      actor:notify(reason, arguments)
    else
      self:say(vendor, actor, 'refuse')
    end

    return false
  end

  self:close(actor, false, true)

  sessions[actor] = { vendor = vendor, traded = false }

  Cable.send(actor, 'fl_vendor_open', vendor, self:get_trade_data(vendor, actor))

  self:say(vendor, actor, 'greeting')

  return true
end

--- Stops trading. The vendor thanks a player who has bought or sold something.
-- @param actor [Player]
-- @param by_client=false [Boolean true if the player has closed the trade panel themselves,
--   so that their client does not have to be told to close it]
-- @param silent=false [Boolean true to keep the vendor from thanking the player]
-- @return [Boolean false if the player was not trading]
function Vendors:close(actor, by_client, silent)
  local session = sessions[actor]

  if !session then return false end

  sessions[actor] = nil

  if !IsValid(actor) then return true end

  if !by_client then
    Cable.send(actor, 'fl_vendor_close')
  end

  if !silent and session.traded then
    self:say(session.vendor, actor, 'thanks')
  end

  return true
end

--- Checks that a player is still entitled to trade with the vendor they have open: it is
-- that vendor, the player is alive and within reach of it, and may still trade with it.
-- Trading is stopped if they are not.
-- @param actor [Player]
-- @param vendor [Entity]
-- @return [Map the session of the player, or nil if they may not trade]
function Vendors:check_session(actor, vendor)
  local session = sessions[actor]

  if !session or !self:is_vendor(vendor) or session.vendor != vendor then return end

  if !actor:Alive() or !Inventories.is_in_reach(actor, vendor) or !self:can_trade(actor, vendor) then
    self:close(actor)

    return
  end

  return session
end

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
    data.money = round_money(currency, math.min(data.money + price, max_price))
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
    data.money = round_money(currency, math.max(data.money - paid, 0))
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
