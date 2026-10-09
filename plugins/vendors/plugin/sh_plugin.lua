--- Vendors are NPC merchants that staff place on the map.
-- A vendor is an `fl_vendor` entity with a model, a name, a description and an idle
-- animation. It has a list of items it sells and a list of items it buys, each with a price
-- that defaults to the `cost` field of the item, an optional finite stock for every item it
-- sells, an optional finite pool of money, a buy-back rate and the currency it trades in.
-- Vendors are saved with the plugin data of the map.
--
-- Staff with the 'manage_vendors' permission place, edit, move and remove vendors with the
-- Vendor Tool: left click creates a vendor or opens the editor of the one that is aimed at,
-- right click removes it and reload moves it. A player who uses a vendor gets the trade
-- panel, which lists what the vendor sells and which of the player's items it buys. Every
-- purchase and sale is carried out by the server (`Vendors:buy`, `Vendors:sell`), which
-- checks the distance, the stock, the money of both sides, the space in the inventory and
-- who may trade.
--
-- A vendor can be limited to factions: a customer then needs one of the listed factions. A
-- schema restricts vendors further through the `PlayerCanUseVendor` hook. The vendor says a
-- few phrases to its customer in the chat, each of which can be replaced in the editor.
-- Their IDs are listed in `Vendors.phrases`: 'greeting' when the trade panel opens, 'refuse'
-- when the customer may not trade, 'no_money' when the customer cannot afford an item,
-- 'no_stock' when an item is sold out, 'broke' when the vendor cannot afford an item and
-- 'thanks' when a customer who has traded leaves. The default text of a phrase is the
-- language phrase 'vendor.phrase.<id>'. `Vendors.entity_class` is the class of the vendor
-- entity and `Vendors.default_model` the model of a vendor whose own model is missing.
--
-- Hooks: `PlayerCanUseVendor` decides who may trade, `AdjustVendorPrice` changes prices,
-- `PlayerCanBuyFromVendor` and `PlayerCanSellToVendor` veto single trades,
-- `PlayerBoughtFromVendor` and `PlayerSoldToVendor` report them, and `VendorSay` changes or
-- mutes what a vendor says.
-- @module [Vendors]

PLUGIN:set_global('Vendors')

Vendors.entity_class = 'fl_vendor'
Vendors.default_model = 'models/humans/group01/male_02.mdl'
Vendors.phrases = { 'greeting', 'refuse', 'no_money', 'no_stock', 'broke', 'thanks' }

require_relative 'cl_hooks'
require_relative 'sv_plugin'
require_relative 'sv_hooks'

--- Registers the 'manage_vendors' level design permission.
function Vendors:RegisterPermissions()
  Bolt:register_permission(
    'manage_vendors',
    'Manage vendors',
    'Grants access to place, edit and remove vendors.',
    'permission.categories.level_design',
    'assistant'
  )
end

--- Checks whether something is a vendor entity.
-- @param entity [Any]
-- @return [Boolean]
function Vendors:is_vendor(entity)
  return isentity(entity) and IsValid(entity) and entity:GetClass() == self.entity_class
end

--- Turns an amount of money into text: the amount followed by the symbol of the currency, or
-- by its translated name if it has no symbol.
-- @param amount [Number]
-- @param currency [String currency ID]
-- @return [String]
function Vendors:format_money(amount, currency)
  local currency_data = isstring(currency) and Currencies:find_currency(currency)

  if !currency_data then
    return tostring(amount)
  end

  return amount..' '..(currency_data.symbol or (t(currency_data.name)))
end

--- Keeps players without the 'manage_vendors' permission from moving vendors with the
-- physics gun.
-- @param actor [Player]
-- @param entity [Entity the entity that is about to be picked up]
-- @return [Boolean false to prevent the pickup, nil otherwise]
function Vendors:PhysgunPickup(actor, entity)
  if self:is_vendor(entity) and !actor:can('manage_vendors') then
    return false
  end
end

--- Keeps players without the 'manage_vendors' permission from using tools on vendors.
-- @param actor [Player]
-- @param trace [Map trace result of the tool use]
-- @param tool_name [String tool ID]
-- @return [Boolean false to block the tool, nil otherwise]
function Vendors:CanTool(actor, trace, tool_name)
  if self:is_vendor(trace.Entity) and !actor:can('manage_vendors') then
    return false
  end
end

--- Keeps players without the 'manage_vendors' permission from using the properties of the
-- context menu on vendors.
-- @param actor [Player]
-- @param property [String property ID]
-- @param entity [Entity]
-- @return [Boolean false to block the property, nil otherwise]
function Vendors:CanProperty(actor, property, entity)
  if self:is_vendor(entity) and !actor:can('manage_vendors') then
    return false
  end
end
