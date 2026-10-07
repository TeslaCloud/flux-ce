local default_msg_data = {
  sender = nil,
  listeners = {},
  data = {},
  position = nil,
  radius = 0,
  filter = nil,
  rich = false,
  size = Config.get('default_font_size', 20),
  text = nil,
  team_chat = false
}

local filters = {}
local client_mode = false

--- Stores a message filter under the specified id. Serverside only.
-- Filters are only stored at the moment, nothing reads them yet.
-- @param id [String unique filter id]
-- @param data [Map filter data]
function Chatbox.add_filter(id, data)
  filters[id] = data
end

--- Checks whether the listener should receive the message. Serverside only.
-- The PlayerCanHear hook can force a message through. Otherwise a radius of 0 reaches
-- every initialized player, a negative radius reaches nobody, and a positive radius
-- reaches the players whose eyes are within it from the position of the message.
-- @param listener [Player]
-- @param message_data [Map message data with radius (Number) and position (Vector or
--   List<Vector>), see Chatbox.add_text]
-- @return [Boolean]
function Chatbox.can_hear(listener, message_data)
  if Plugin.call('PlayerCanHear', listener, message_data) then
    return true
  end

  if IsValid(listener) and listener:has_initialized() then
    local position, radius = message_data.position, message_data.radius

    if !isnumber(radius) then return false end
    if radius == 0 then return true end
    if radius < 0 then return false end

    if istable(position) then
      for k, v in pairs(position) do
        if isvector(v) and v:Distance(listener:EyePos()) <= radius then
          return true
        end
      end
    end

    if isvector(position) and position:Distance(listener:EyePos()) <= radius then
      return true
    end
  end

  return false
end

--- Builds a chat message from the arguments and sends it to the listeners that can
-- hear it. Serverside only.
-- Strings are displayed as text, numbers set the font size of the following text,
-- colors set its color, players and entities are displayed by their names. Tables with
-- is_data = true are displayed as icons or images. Any other table is merged into the
-- message options: sender, position, radius (0 is global), size, should_translate.
-- ```
-- -- Message for everyone.
-- Chatbox.add_text(nil, Color(255, 200, 0), 'The server restarts in 5 minutes!')
--
-- -- Message from a player that is heard within 300 units of them.
-- Chatbox.add_text(nil,
--   { icon = 'fa-shield-alt', size = 14, margin = 8, is_data = true },
--   _team.GetColor(player:Team()), player, Color(255, 255, 255), ': ', text,
--   { sender = player, position = player:GetPos(), radius = 300 }
-- )
--
-- -- Message for certain players only.
-- Chatbox.add_text(Bolt:get_staff(), Color(234, 255, 208), '@staff ', player, ': ', text)
-- ```
-- @param listeners [List<Player>/Player the receivers, nil to send to all players]
-- @param ... [Vararg pieces of the message and option tables]
-- @see [Chatbox.can_hear]
function Chatbox.add_text(listeners, ...)
  local message_data = {
    sender = nil,
    listeners = listeners or {},
    data = {},
    position = nil,
    radius = 0,
    filter = nil,
    rich = false,
    size = Config.get('default_font_size', 20),
    text = nil,
    team_chat = false
  }

  if !istable(listeners) then
    if IsValid(listeners) then
      listeners = { listeners }
    else
      listeners = _player.all()
    end
  end

  local last_string = false

  -- Compile the initial message data table.
  for k, v in ipairs({ ... }) do
    if isstring(v) then
      if !last_string then
        table.insert(message_data.data, v)
      else
        local str = table.last(message_data.data)
        message_data.data[#message_data.data] = str..v
      end

      if k == 1 then
        message_data.text = v
      end

      last_string = true
    else
      last_string = false

      if isnumber(v) then
        table.insert(message_data.data, v)
      elseif IsColor(v) then
        table.insert(message_data.data, v)
      elseif istable(v) then
        if !v.is_data and !client_mode then
          table.merge(message_data, v)
        else
          table.insert(message_data.data, v)
        end
      elseif IsValid(v) then
        table.insert(message_data.data, v)
      end
    end
  end

  for k, v in ipairs(listeners) do
    local data = message_data

    hook.run('AdjustMessageData', v, data)

    if Chatbox.can_hear(v, data) then
      Cable.send(v, 'fl_chat_message_add', data)
    end
  end
end

--- Toggles the mode in which Chatbox.add_text displays every table instead of merging
-- tables into the message options. Enabled while relaying chat.AddText of a client.
-- @warning [Internal]
-- @param val [Boolean]
function Chatbox.set_client_mode(val)
  client_mode = val
end

--- Joins the strings of a message into a single string. Players and entities are
-- replaced with their names, numbers and other values are skipped.
-- @param message_data [List pieces of a message, such as the data of a message]
-- @param concatenator='' [String separator to put between the pieces]
-- @return [String]
function Chatbox.message_to_string(message_data, concatenator)
  local to_string = {}

  for k, v in pairs(message_data) do
    if isnumber(v) then continue end

    if isstring(v) then
      table.insert(to_string, v)
    elseif IsValid(v) then
      local name = ''

      if v:IsPlayer() then
        name = hook.run('GetPlayerName', v) or v:name()
      else
        name = tostring(v) or v:GetClass()
      end

      table.insert(to_string, name)
    end
  end

  return table.concat(to_string, concatenator)
end

--- Makes the player say the text in the chat, by default to all players.
-- Runs the PlayerSay hook first, which may change or suppress the text. The icon
-- and colors come from the ChatboxGetPlayerIcon, ChatboxGetPlayerColor and
-- ChatboxGetMessageColor hooks, and the ChatboxAdjustPlayerSay hook can alter the
-- finished message. Serverside only.
-- @param player [Player the speaker]
-- @param text [String the message]
-- @param team_chat=nil [Boolean whether the message was sent to the team chat]
function Chatbox.player_say(player, text, team_chat)
  if !IsValid(player) then return end

  local player_say_override = hook.run('PlayerSay', player, text, team_chat)

  if isstring(player_say_override) then
    if player_say_override == '' then return end

    text = player_say_override
  end

  text = text:trim()

  local message = {
    hook.run('ChatboxGetPlayerIcon', player, text, team_chat) or {},
    hook.run('ChatboxGetPlayerColor', player, text, team_chat) or _team.GetColor(player:Team()),
    player,
    hook.run('ChatboxGetMessageColor', player, text, team_chat) or Color(255, 255, 255),
    ': ',
    text,
    { sender = player }
  }

  hook.run('ChatboxAdjustPlayerSay', player, text, message)

  Chatbox.add_text(nil, unpack(message))
end

Cable.receive('fl_chat_text_add', function(player, ...)
  if !IsValid(player) then return end

  Chatbox.set_client_mode(true)
  Chatbox.add_text(player, ...)
  Chatbox.set_client_mode(false)
end)

Cable.receive('fl_chat_player_say', function(player, text, team_chat)
  Chatbox.player_say(player, text, team_chat)
end)
