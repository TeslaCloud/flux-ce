--- The vendor editor on the server: opens it for staff with the 'manage_vendors' permission
-- and handles the settings it saves and the removal it asks for.

Cable.check_networked_string('fl_vendor_edit')

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
