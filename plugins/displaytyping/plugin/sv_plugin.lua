--- Server side of the Display Typing plugin: keeps track of who is typing and tells the
-- players near them.
-- Every typing player has a state with what their client has reported. `DisplayTyping:relay`
-- sends it to the players who are within the range of the kind of speech (a little beyond
-- it, so that a bubble is known before it fades in) and tells those who have left the range
-- that the typing is over for them. Nothing is sent about a player who is dead, hidden or in
-- observer mode, to players who have turned typing bubbles off, or more often than every
-- `relay_interval` seconds per typing player. The text itself is only passed on if the
-- client has reported it as text that others may see and the 'display_exact_message' config
-- is enabled; otherwise the receivers get its outline.

local typists = DisplayTyping.typists or {}
DisplayTyping.typists = typists

DisplayTyping.relay_interval = 0.2
DisplayTyping.scan_interval = 0.5
DisplayTyping.idle_timeout = 10
DisplayTyping.report_limit = 10

Cable.check_networked_string('fl_typing_update')
Cable.check_networked_string('fl_typing_stop')

--- Checks whether a player is typing in the chatbox, as far as their client has reported.
-- @param target [Player]
-- @return [Boolean]
function DisplayTyping:is_typing(target)
  return typists[target] != nil
end

--- Checks whether other players may be shown that a player is typing. They may not while
-- the player is dead, not initialized, vanished, in observer mode or not drawn (unless they
-- have fallen over and a ragdoll stands in for them), or when the PlayerCanDisplayTyping
-- hook says so.
-- @param actor [Player the typing player]
-- @return [Boolean]
function DisplayTyping:can_display(actor)
  if !actor:Alive() or !actor:has_initialized() then return false end
  if actor.is_vanished or actor:get_nv('observer') then return false end
  if actor:GetNoDraw() and !self:get_ragdoll(actor) then return false end

  --- Asks whether other players may see that a player is typing. Called on the server for
  -- every typing player who is alive and visible, each time their typing is about to be sent
  -- to the players nearby, which is up to five times a second.
  -- @param actor [Player the typing player]
  -- @return [Boolean return false to hide the typing of the player from everyone]
  return hook.Run('PlayerCanDisplayTyping', actor) != false
end

--- Checks whether a player is sent the typing of others: bots and players who have not
-- been initialized or have turned typing bubbles off in their client settings are not.
-- @param viewer [Player]
-- @return [Boolean]
function DisplayTyping:can_receive(viewer)
  if !viewer:has_initialized() or viewer:IsBot() then return false end

  if ClientSettings and viewer:get_setting('display_typing_bubbles', true) == false then
    return false
  end

  return true
end

--- Counts a typing report of a player against the limit of `report_limit` reports a second.
-- @param actor [Player the player who has sent the report]
-- @param now [Number current CurTime()]
-- @return [Boolean false if the player has sent too many reports this second]
function DisplayTyping:accept_report(actor, now)
  if now >= (actor.fl_typing_window or 0) then
    actor.fl_typing_window = now + 1
    actor.fl_typing_reports = 0
  end

  actor.fl_typing_reports = actor.fl_typing_reports + 1

  return actor.fl_typing_reports <= self.report_limit
end

--- Records what a player is typing and passes it on to the players nearby, at once if
-- nothing has been sent about this player for `relay_interval` seconds and otherwise on the
-- next LazyTick after that. The typing ends by itself if no report follows for
-- `idle_timeout` seconds.
-- @param actor [Player the typing player]
-- @param text [String the text being typed or its outline, not empty]
-- @param exact=false [Boolean true if the text is what the player is typing and others may
--   see it; otherwise it is reduced to its outline]
-- @param range=1 [Number multiplier of the 'display_typing_range' config for this text,
--   limited to `DisplayTyping.max_range`]
function DisplayTyping:set_typing(actor, text, exact, range)
  local now = CurTime()
  local state = typists[actor]
  local started = state == nil

  if utf8.len(text) then
    text = Chatbox.limit_text(text)
  else
    text = self.placeholder
    exact = false
  end

  exact = exact == true
  range = tonumber(range) or 1

  if range != range then
    range = 1
  end

  range = math.Clamp(range, 0, self.max_range)

  local outline = self:outline(text)

  if !exact then
    text = outline
  end

  if !state then
    state = { recipients = {}, next_relay = 0, next_scan = 0 }
    typists[actor] = state
  end

  if state.text != text or state.exact != exact or state.range != range then
    state.dirty = true
  end

  state.text = text
  state.outline = outline
  state.exact = exact
  state.range = range
  state.expires = now + self.idle_timeout

  if started then
    --- Called on the server when a player starts typing in the chatbox, that is when the
    -- first report of a text arrives from their client. A client can make this happen up
    -- to ten times a second, so limit anything costly or audible a handler does.
    -- @param actor [Player the player who has started typing]
    -- @param text [String the text so far if the client reported it as text that others
    --   may see, otherwise its outline (see `DisplayTyping:outline`)]
    hook.Run('PlayerStartedTyping', actor, text)

    if typists[actor] != state then return end
  end

  if state.dirty and now >= state.next_relay then
    self:relay(actor, state, now)
  end
end

--- Ends the typing of a player and tells the players who were shown it.
-- @param actor [Player]
function DisplayTyping:stop_typing(actor)
  local state = typists[actor]

  if !state then return end

  typists[actor] = nil

  local receivers = {}

  for viewer in pairs(state.recipients) do
    if IsValid(viewer) then
      table.insert(receivers, viewer)
    end
  end

  if #receivers > 0 then
    Cable.send(receivers, 'fl_typing_stop', actor:EntIndex())
  end

  --- Called on the server when a player is no longer typing: they have sent or cleared
  -- the text, closed the chatbox, left the server, or reported nothing for
  -- `DisplayTyping.idle_timeout` seconds.
  -- @param actor [Player the player who has stopped typing]
  hook.Run('PlayerStoppedTyping', actor)
end

--- Brings the players near a typing player up to date. Works out who should see the typing
-- now, tells the players who no longer should that it is over, and sends the state to the
-- players who have come into range, or to everyone in range if it has changed.
-- @param actor [Player the typing player]
-- @param state [Map typing state of the player]
-- @param now [Number current CurTime()]
function DisplayTyping:relay(actor, state, now)
  state.next_relay = now + self.relay_interval
  state.next_scan = now + self.scan_interval

  local previous = state.recipients
  local current, everyone, added, removed = {}, {}, {}, {}

  if self:can_display(actor) then
    local ragdoll = self:get_ragdoll(actor)
    local origin = ragdoll and ragdoll:WorldSpaceCenter() or actor:EyePos()
    local radius = self:get_range() * state.range
    local enter, leave = (radius * 1.15) ^ 2, (radius * 1.35) ^ 2

    for k, v in player.Iterator() do
      if v != actor and self:can_receive(v) and origin:DistToSqr(v:EyePos()) <= (previous[v] and leave or enter) then
        current[v] = true

        table.insert(everyone, v)

        if !previous[v] then
          table.insert(added, v)
        end
      end
    end
  end

  for viewer in pairs(previous) do
    if !current[viewer] and IsValid(viewer) then
      table.insert(removed, viewer)
    end
  end

  state.recipients = current

  local index = actor:EntIndex()
  local exact = state.exact and self:live_text_allowed()

  if #removed > 0 then
    Cable.send(removed, 'fl_typing_stop', index)
  end

  local receivers = (state.dirty or state.sent_exact != exact) and everyone or added

  state.dirty = false
  state.sent_exact = exact

  if #receivers > 0 then
    Cable.send(receivers, 'fl_typing_update', index, exact and state.text or state.outline, exact)
  end
end
