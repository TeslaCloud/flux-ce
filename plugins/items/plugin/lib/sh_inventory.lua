--- The Inventories library is the registry of all inventories, `Inventories.all` and
-- `Inventories.find`. Every `Inventory` registers itself here under its id when it is
-- created. On the server `Inventories.place_items` puts the items loaded from the database
-- into the inventories that hold them.
-- @module [Inventories]

mod 'Inventories'

local stored = Inventories.stored or {}
Inventories.stored = stored

--- Returns all the inventory classes currently loaded on the server.
-- @return [Map inventories]
function Inventories.all()
  return stored
end

--- Finds a specific inventory by its id.
-- @param id [Number]
-- @return [Inventory]
function Inventories.find(id)
  return stored[id]
end
