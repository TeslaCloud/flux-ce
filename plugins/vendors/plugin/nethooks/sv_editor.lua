--- Server-side receivers of the vendor editor: saving the settings of a vendor and removing
-- it, for staff with the 'manage_vendors' permission.

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
