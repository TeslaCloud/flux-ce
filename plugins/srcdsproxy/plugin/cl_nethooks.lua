--- Client side of the server transfer areas: the server starts and cancels the countdown of
-- a transfer area; the client only receives it here and draws it.

Cable.receive('fl_proxy_area_countdown', function(backend, end_time)
  SrcdsProxy.area_countdown = { backend = tostring(backend), end_time = tonumber(end_time) or CurTime() }
end)

Cable.receive('fl_proxy_area_cancel', function()
  SrcdsProxy.area_countdown = nil
end)
