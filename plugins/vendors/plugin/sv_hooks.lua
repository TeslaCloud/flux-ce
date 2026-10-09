--- Server-side hooks of the Vendors plugin: loads and saves the vendors, keeps them through
-- a map cleanup and stops the trading of players who are no longer entitled to it.

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
