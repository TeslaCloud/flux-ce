--- Life of vendors on the map: creating, changing, moving and removing them, and saving
-- them with the plugin data of the map and loading them back.

local ipairs = ipairs

--- Turns a map of item ID to entry into a list of entries with an `id` field, which survives
-- being saved as JSON whatever the IDs look like.
-- @param items [Map item ID to entry]
-- @return [List<Map>]
local function items_to_list(items)
  local entries = {}

  for id, entry in SortedPairs(items) do
    entries[#entries + 1] = { id = id, price = entry.price, stock = entry.stock }
  end

  return entries
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
      vendors[#vendors + 1] = self:to_saveable(v)
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
