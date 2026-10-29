--- Server-side receivers of the Chatbox plugin: the text that a player submits from the
-- chatbox, and what a client adds with `chat.AddText`, which is relayed to the chatbox of
-- that client at most `Chatbox.relay_limit` times a second, each piece cut to the longest
-- message.

local IsValid = IsValid

Cable.receive('fl_chat_text_add', function(actor, ...)
  if !IsValid(actor) then return end

  local cur_time = CurTime()

  if cur_time >= (actor.fl_chat_relay_window or 0) then
    actor.fl_chat_relay_window = cur_time + 1
    actor.fl_chat_relay_count = 0
  end

  actor.fl_chat_relay_count += 1

  if actor.fl_chat_relay_count > Chatbox.relay_limit then return end

  local pieces = { ... }

  for index, piece in ipairs(pieces) do
    if isstring(piece) then
      pieces[index] = Chatbox.limit_text(piece)
    end
  end

  Chatbox.set_client_mode(true)

  local success, exception = pcall(Chatbox.add_text, actor, unpack(pieces))

  Chatbox.set_client_mode(false)

  if !success then
    ErrorNoHalt('[Flux - Chatbox] Failed to relay chat.AddText of '..tostring(actor)..': '..tostring(exception)..'\n')
  end
end)

Cable.receive('fl_chat_player_say', function(actor, text, team_chat)
  Chatbox.submit(actor, text, team_chat)
end)
