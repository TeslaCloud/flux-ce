--- Client side of the Display Typing plugin: tells what kind of speech a text is and reports
-- what the local player is typing to the server. The reports are throttled, a text that
-- must not be shown to others is reduced to its outline before it is sent, and nothing is
-- sent again while what would be sent stays the same.

DisplayTyping.report_interval = 0.25
DisplayTyping.keepalive_interval = 3

--- Removes the dots, the ellipsis and the spaces a label ends with, as the bubble draws
-- animated dots of its own next to it.
-- @param label [String]
-- @return [String the trimmed label, or the label as it was if nothing else is left of it]
local function trim_label(label)
  local trimmed = label
  local ellipsis = DisplayTyping.placeholder

  repeat
    local before = trimmed

    trimmed = trimmed:gsub('[%.%s]+$', '')

    if trimmed:end_with(ellipsis) then
      trimmed = trimmed:sub(1, #trimmed - #ellipsis)
    end
  until trimmed == before

  if trimmed == '' then
    return label
  end

  return trimmed
end

--- Reads a client setting of the plugin. Settings are on while the Settings plugin is not
-- loaded.
-- @param id [String setting id]
-- @return [Boolean false if the player has turned the setting off]
function DisplayTyping:get_preference(id)
  if ClientSettings then
    return ClientSettings:get(id, true) != false
  end

  return true
end

--- Tells what kind of speech a text is, by asking the DisplayTypingGetKind hook and then the
-- older DisplayTypingTextType and DisplayTypingAdjustFadeoffMultiplier hooks.
-- @param target [Player the player who is typing]
-- @param text [String the text being typed, or its outline]
-- @return [Map the kind: id (String), label (String translated label), color (Color, or nil
--   for the accent color of the bubble), range (Number multiplier of the
--   'display_typing_range' config) and live (Boolean whether the text may be shown); nil if
--   no bubble should be shown for this text]
function DisplayTyping:get_kind(target, text)
  --- Asks what kind of speech a player is typing, which decides the label, the color and
  -- the range of their typing bubble. Called on the client whenever the text of a typing
  -- player nearby changes, and for the local player on every change of their own text, to
  -- decide what is reported to the server. The text is the outline of what is typed
  -- (see `DisplayTyping:outline`) whenever the viewer may not see the text itself, so look
  -- at what it starts and ends with.
  -- @param target [Player the player who is typing]
  -- @param text [String the text being typed, or its outline]
  -- @return [String/Map/Boolean ID of a kind registered with
  --   `DisplayTyping:register_kind`; or a kind definition with the same fields; or false to
  --   show no bubble for this text. When nothing is returned the DisplayTypingTextType and
  --   DisplayTypingAdjustFadeoffMultiplier hooks are asked instead]
  local result = hook.Run('DisplayTypingGetKind', target, text)

  if result == false then return end

  local fallback = self.kinds.typing
  local kind = istable(result) and result or isstring(result) and self.kinds[result]

  if kind then
    local name = t(kind.name or fallback.name)

    return {
      id = kind.id or 'custom',
      label = trim_label(name),
      color = kind.color,
      range = math.Clamp(tonumber(kind.range) or 1, 0, self.max_range),
      live = kind.live != false
    }
  end

  --- Asks for the label of the typing bubble of a player. Called on the client when the
  -- DisplayTypingGetKind hook has not decided the kind of speech: whenever the text of a
  -- typing player nearby changes, and for the local player on every change of their own
  -- text. A text that gets a label is treated as speech, so it may be shown as it is typed
  -- even if it is a command.
  -- @param target [Player the player who is typing]
  -- @param text [String the text being typed, or its outline (see
  --   `DisplayTyping:outline`) if the viewer may not see the text itself]
  -- @return [String label to draw; the translated 'typing' label is used when nothing is
  --   returned]
  local label = hook.Run('DisplayTypingTextType', target, text)
  --- Lets plugins scale the distance from which the typing bubble of a player is visible.
  -- Called on the client right after the DisplayTypingTextType hook, under the same
  -- conditions.
  -- @param target [Player the player who is typing]
  -- @param text [String the text being typed, or its outline (see
  --   `DisplayTyping:outline`) if the viewer may not see the text itself]
  -- @return [Number multiplier of the squared distance at which the bubble has faded out,
  --   so 4 doubles the range; 1 when nothing is returned]
  local multiplier = tonumber(hook.Run('DisplayTypingAdjustFadeoffMultiplier', target, text)) or 1
  local name = isstring(label) and label or t(fallback.name)

  return {
    id = isstring(label) and 'custom' or fallback.id,
    label = trim_label(name),
    color = fallback.color,
    range = math.Clamp(math.sqrt(math.max(multiplier, 0)), 0, self.max_range),
    live = isstring(label) or !text:is_command()
  }
end

--- Checks whether a player is known to be typing. On the client that is known for the local
-- player and for the players whose typing bubbles the server has sent, which are the ones
-- nearby.
-- @param target [Player]
-- @return [Boolean]
function DisplayTyping:is_typing(target)
  if !IsValid(target) then return false end

  if target == PLAYER then
    return self.reported != nil
  end

  local bubble = self.bubbles[target:EntIndex()]

  return bubble != nil and bubble.typing == true
end

--- Takes the text the local player is typing and reports it to the server if what others
-- should see has changed: at once if nothing has been sent for `report_interval` seconds,
-- otherwise when that time is up. An empty text, or one that no bubble is shown for, ends
-- the typing right away. While the player keeps typing a text that looks the same to others,
-- the report is repeated every `keepalive_interval` seconds so that the server knows they
-- are still at it.
-- @param text [String current contents of the chat text entry]
function DisplayTyping:report(text)
  local payload, exact, range = '', false, 1

  if isstring(text) and text != '' and IsValid(PLAYER) then
    local kind = self:get_kind(PLAYER, text)

    if kind then
      exact = kind.live and self:live_text_allowed()
      payload = exact and text or self:outline(text)
      range = kind.range
    end
  end

  if payload == '' then
    self.pending_report = nil

    timer.Remove('fl_typing_report')

    if self.reported then
      self.reported = nil

      Cable.send('fl_typing_report', '')
    end

    return
  end

  local now = RealTime()
  local last = self.reported

  if last and last.text == payload and last.exact == exact and last.range == range
  and now - last.time < self.keepalive_interval then
    self.pending_report = nil

    timer.Remove('fl_typing_report')

    return
  end

  self.pending_report = { text = payload, exact = exact, range = range }

  local wait = (self.next_report or 0) - now

  if wait <= 0 then
    self:flush_report()
  elseif !timer.Exists('fl_typing_report') then
    timer.Create('fl_typing_report', wait, 1, function()
      DisplayTyping:flush_report()
    end)
  end
end

--- Sends the report that is waiting to be sent, if there is one, and starts the next
-- `report_interval`.
function DisplayTyping:flush_report()
  local pending = self.pending_report

  if !pending then return end

  local now = RealTime()

  pending.time = now

  self.pending_report = nil
  self.reported = pending
  self.next_report = now + self.report_interval

  timer.Remove('fl_typing_report')

  Cable.send('fl_typing_report', pending.text, pending.exact, pending.range)
end
