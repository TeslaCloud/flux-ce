--- Server-side hooks of the Display Typing plugin: receives the typing reports of the
-- clients and keeps the players near every typing player up to date.

--- Looks after the typing players eight times a second: ends the typing of those who have
-- reported nothing for too long, sends changes that had to wait for the relay interval and
-- checks again who is in range of each of them every `scan_interval` seconds.
function DisplayTyping:LazyTick()
  local now = CurTime()

  for actor, state in pairs(self.typists) do
    if !IsValid(actor) then
      self.typists[actor] = nil
    elseif now >= state.expires then
      self:stop_typing(actor)
    elseif now >= state.next_scan or state.dirty and now >= state.next_relay then
      self:relay(actor, state, now)
    end
  end
end

--- Ends the typing of a player who leaves the server.
-- @param actor [Player]
function DisplayTyping:PlayerDisconnected(actor)
  self:stop_typing(actor)
end

Cable.receive('fl_typing_report', function(actor, text, exact, kind_id)
  if !IsValid(actor) or !isstring(text) then return end

  if text == '' then
    DisplayTyping:stop_typing(actor)

    return
  end

  if #text > Config.get('max_message_length', 512) * 4 then return end
  if !DisplayTyping:accept_report(actor, CurTime()) then return end

  DisplayTyping:set_typing(actor, text, exact, kind_id)
end)
