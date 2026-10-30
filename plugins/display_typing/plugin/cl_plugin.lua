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

--- Reads a client setting of the plugin.
-- @param id [String setting id]
-- @return [Boolean false if the player has turned the setting off]
function DisplayTyping:get_preference(id)
  return ClientSettings:get(id, true) != false
end

--- Tells what kind of speech a text is and what its typing bubble shows: the kind comes from
-- the GetTypingKind hook, and the AdjustTypingDisplay hook changes what the bubble shows.
-- @param target [Player the player who is typing]
-- @param text [String the text being typed, or its outline]
-- @return [Map what the bubble shows: id (String ID of the kind), label (String translated
--   label), color (Color, or nil for the accent color of the bubble), range (Number
--   multiplier of the 'display_typing_range' config) and live (Boolean whether the text may
--   be shown); nil if no bubble should be shown for this text]
function DisplayTyping:get_kind(target, text)
  --- Asks what kind of speech a player is typing, which decides the label, the color and
  -- the range of their typing bubble. Called on the client whenever the text of a typing
  -- player nearby changes, and for the local player on every change of their own text, to
  -- decide what is reported to the server. The text is the outline of what is typed
  -- (see `DisplayTyping:outline`) whenever the viewer may not see the text itself, so look
  -- at what it starts and ends with.
  -- @param target [Player the player who is typing]
  -- @param text [String the text being typed, or its outline]
  -- @return [String/Boolean ID of a kind registered with `DisplayTyping:register_kind`, or
  --   false to show no bubble for this text. The 'typing' kind is used when nothing or an
  --   ID that is not registered is returned]
  local result = hook.Run('GetTypingKind', target, text)

  if result == false then return end

  local fallback = self.kinds.typing
  local kind = isstring(result) and self.kinds[result]
  local display

  if kind then
    display = {
      id = kind.id,
      label = t(kind.name),
      color = kind.color,
      range = kind.range,
      live = kind.live
    }
  else
    display = {
      id = fallback.id,
      label = t(fallback.name),
      color = fallback.color,
      range = fallback.range,
      live = !Flux.Command:is_command(text)
    }
  end

  --- Lets plugins change what the typing bubble of a player shows. Called on the client
  -- right after `GetTypingKind` has decided the kind of speech, under the same conditions,
  -- and not when it has returned false. Handlers change the fields of `display` in place
  -- and return nothing. The server sends the bubble within the range of the kind that `id`
  -- names, so a different `range` only changes the distance it fades out at on the
  -- viewer's client; set `id` to a kind registered on both realms to change both.
  -- ```
  -- function MyPlugin:AdjustTypingDisplay(target, text, display)
  --   if display.id == 'talking' and text:end_with('?') then
  --     display.label = t'ui.my_plugin.asking'
  --   end
  -- end
  -- ```
  -- @param target [Player the player who is typing]
  -- @param text [String the text being typed, or its outline]
  -- @param display [Map what the bubble shows: id (String ID of the kind, reported to the
  --   server for the local player), label (String translated label), color (Color of the
  --   label and the dots, nil for the accent color of the bubble), range (Number multiplier
  --   of the 'display_typing_range' config) and live (Boolean whether the text may be shown
  --   as it is typed)]
  hook.Run('AdjustTypingDisplay', target, text, display)

  display.label = trim_label(isstring(display.label) and display.label or t(fallback.name))
  display.range = math.Clamp(tonumber(display.range) or 1, 0, self.max_range)
  display.live = display.live != false

  return display
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
-- are still at it. A report carries the ID of the kind of speech, from which the server
-- takes the range of the bubble.
-- @param text [String current contents of the chat text entry]
function DisplayTyping:report(text)
  local payload, exact, kind_id = '', false, nil

  if isstring(text) and text != '' and IsValid(PLAYER) then
    local kind = self:get_kind(PLAYER, text)

    if kind then
      exact = kind.live and self:live_text_allowed()
      payload = exact and text or self:outline(text)
      kind_id = kind.id
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

  if last and last.text == payload and last.exact == exact and last.kind == kind_id
  and now - last.time < self.keepalive_interval then
    self.pending_report = nil

    timer.Remove('fl_typing_report')

    return
  end

  self.pending_report = { text = payload, exact = exact, kind = kind_id }

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

  Cable.send('fl_typing_report', pending.text, pending.exact, pending.kind)
end
