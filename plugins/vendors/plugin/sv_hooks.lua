--- Server-side hooks of the Vendors plugin: loads and saves the vendors, keeps them through
-- a map cleanup, stops the trading of players who are no longer entitled to it, and handles
-- the requests of the trade panel and of the vendor editor.

local refresh_interval = 0.5

Cable.check_networked_string('fl_vendor_open')
Cable.check_networked_string('fl_vendor_update')
Cable.check_networked_string('fl_vendor_change')
Cable.check_networked_string('fl_vendor_edit')

--- Spawns the saved vendors when the framework loads its data.
function Vendors:LoadData()
  self:load()
end

--- Saves the vendors, with their stock and money, when the framework saves its data.
function Vendors:SaveData()
  self:save()
end

--- Saves the vendors before the map is cleaned up, which removes them.
function Vendors:PreCleanupMap()
  self:save()
end

--- Spawns the vendors again once the map has been cleaned up.
function Vendors:PostCleanupMap()
  self:load()
end

--- Stops the trading of the players who have died, walked out of reach of their vendor or
-- whose vendor is gone, so that it does not depend on the client closing the trade panel.
function Vendors:OneSecond()
  for actor, session in pairs(self.sessions) do
    if !IsValid(actor) then
      self.sessions[actor] = nil
    elseif !self:is_vendor(session.vendor) then
      self:close(actor, false, true)
    elseif !actor:Alive() or !Inventories.is_in_reach(actor, session.vendor) then
      self:close(actor)
    end
  end
end

--- Forgets the trading session of a player who has left.
-- @param actor [Player]
function Vendors:PlayerDisconnected(actor)
  self.sessions[actor] = nil
end

--- Stops the trading of a player whose active character changes.
-- @param owner [Player]
-- @param character [Character]
function Vendors:OnActiveCharacterSet(owner, character)
  self:close(owner, false, true)
end

--- Closes the trade panel of the customers of a vendor that is being removed.
-- @param entity [Entity]
function Vendors:EntityRemoved(entity)
  if !self:is_vendor(entity) then return end

  for k, v in ipairs(self:get_customers(entity)) do
    self:close(v, false, true)
  end
end

Cable.receive('fl_vendor_buy', function(actor, vendor, item_id)
  if !isstring(item_id) then return end

  Vendors:buy(actor, vendor, item_id)
end)

Cable.receive('fl_vendor_sell', function(actor, vendor, instance_id)
  if !isnumber(instance_id) then return end

  Vendors:sell(actor, vendor, instance_id)
end)

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

Cable.receive('fl_vendor_save', function(actor, vendor, data)
  if !actor:can('manage_vendors') or !Vendors:is_vendor(vendor) or !istable(data) then return end

  local applied = Vendors:apply(vendor, data)

  Vendors:save()

  if isstring(data.model) and data.model:Trim():lower() != applied.model:lower() then
    actor:notify('error.vendor.invalid_model')
  end

  actor:notify('notification.vendor.saved')
end)

Cable.receive('fl_vendor_remove', function(actor, vendor)
  if !actor:can('manage_vendors') or !Vendors:is_vendor(vendor) then return end

  Vendors:remove(vendor)
  Vendors:save()

  actor:notify('notification.vendor.removed')
end)
