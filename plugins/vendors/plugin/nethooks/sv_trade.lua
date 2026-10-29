--- Server-side receivers of the trade panel: the purchases and sales it asks for, which
-- `Vendors:buy` and `Vendors:sell` check and carry out.

Cable.receive('fl_vendor_buy', function(actor, vendor, item_id)
  if !isstring(item_id) then return end

  Vendors:buy(actor, vendor, item_id)
end)

Cable.receive('fl_vendor_sell', function(actor, vendor, instance_id)
  if !isnumber(instance_id) then return end

  Vendors:sell(actor, vendor, instance_id)
end)
