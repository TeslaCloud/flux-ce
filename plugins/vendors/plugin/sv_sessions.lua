--- Trading sessions: who is trading with which vendor, who may trade, and the messages that
-- open, refresh and close the trade panel of the customers.
--
-- A player who is trading has a session in `Vendors.sessions`, a table with the `vendor`
-- and the `traded` flag, from `Vendors:open` until `Vendors:close`.

local sessions = Vendors.sessions or {}
Vendors.sessions = sessions

local use_interval = 1
local refresh_interval = 0.5

Cable.check_networked_string('fl_vendor_open')
Cable.check_networked_string('fl_vendor_update')
Cable.check_networked_string('fl_vendor_change')

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

Cable.receive('fl_vendor_close', function(actor)
  Vendors:close(actor, true)
end)

Cable.receive('fl_vendor_refresh', function(actor, vendor)
  local cur_time = CurTime()

  if actor.next_vendor_refresh and actor.next_vendor_refresh > cur_time then return end

  actor.next_vendor_refresh = cur_time + refresh_interval

  if Vendors:check_session(actor, vendor) then
    Vendors:update_customers(vendor, actor)
  end
end)
