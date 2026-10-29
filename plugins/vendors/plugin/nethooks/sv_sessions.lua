--- Server-side receivers of the trading sessions: a customer closing the trade panel, and
-- asking for fresh prices at most twice a second.

local refresh_interval = 0.5

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
