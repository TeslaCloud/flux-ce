--- The vendor editor on the server: opens it for staff with the 'manage_vendors' permission.
-- The settings it saves and the removal it asks for are received in `nethooks/sv_editor.lua`.

if !Vendors then
  PLUGIN:set_global('Vendors')
end

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
