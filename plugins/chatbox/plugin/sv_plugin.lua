--- Server side of the Chatbox plugin: builds chat messages, decides who can hear them, sends
-- them to the clients, and turns what players type into messages.

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
  --- Lets plugins make a listener receive a message regardless of its radius. Called on the
  -- server by `Chatbox.can_hear` before the radius is checked; gamemode hooks are not called.
  -- @param listener [Player]
  -- @param message_data [Map message data, see Chatbox.add_text]
  -- @return [Boolean return true to let the listener receive the message. Any other value
  --   leaves the decision to the radius check, so a handler cannot block a message]
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
--   team.GetColor(actor:Team()), actor, Color(255, 255, 255), ': ', text,
--   { sender = actor, position = actor:GetPos(), radius = 300 }
-- )
--
-- -- Message for certain players only.
-- Chatbox.add_text(Bolt:get_staff(), Color(234, 255, 208), '@staff ', actor, ': ', text)
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
      listeners = player.GetAll()
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
          table.Merge(message_data, v)
        else
          table.insert(message_data.data, v)
        end
      elseif IsValid(v) then
        table.insert(message_data.data, v)
      end
    end
  end

  for k, v in ipairs(listeners) do
    local data = table.Copy(message_data)

    --- Lets plugins change a message before it is checked against a listener and sent to them.
    -- Called on the server once for every potential listener. Every listener gets their own
    -- copy of the message data, so a change made for one of them does not affect the others.
    -- @param listener [Player the player who may receive the message]
    -- @param message_data [Map message data: data (the pieces), sender, position, radius, size
    --   and the other options given to Chatbox.add_text]
    hook.Run('AdjustMessageData', v, data)

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
        --- Asks for the name to display for a player, here while a message is being turned
        -- into a string. It is the hook behind `Player:name`; `Chatbox.compile` also runs it
        -- on the client for the players in a message, unless the ShouldProcessPlayerName hook
        -- returns false.
        -- @param target [Player]
        -- @return [String name to use instead of the name of the player]
        name = hook.Run('GetPlayerName', v) or v:name()
      else
        name = tostring(v)
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
-- @param actor [Player the speaker]
-- @param text [String the message]
-- @param team_chat=nil [Boolean whether the message was sent to the team chat]
function Chatbox.player_say(actor, text, team_chat)
  if !IsValid(actor) then return end

  --- The PlayerSay hook of GMod, run by the chatbox itself: chat typed into the chatbox is
  -- sent through its own network message, so the engine never runs the hook. Called on the
  -- server before the text is turned into a chat message.
  -- @param actor [Player the speaker]
  -- @param text [String the text as it was typed]
  -- @param team_chat [Boolean whether the message is meant for the team chat, as sent by the
  --   chatbox of the speaker; nil when Chatbox.player_say is called without it]
  -- @return [String text to say instead; an empty string suppresses the message, which is how
  --   commands are kept out of the chat]
  local player_say_override = hook.Run('PlayerSay', actor, text, team_chat)

  if isstring(player_say_override) then
    if player_say_override == '' then return end

    text = player_say_override
  end

  text = text:strip()

  local message = {
    --- Provides the icon displayed before the name of a player in what they say. Called on
    -- the server by `Chatbox.player_say`. The Chatbox plugin's own handler supplies the
    -- default icon.
    -- @param actor [Player the speaker]
    -- @param text [String the message]
    -- @param team_chat [Boolean whether the message is meant for the team chat]
    -- @return [Map icon piece for Chatbox.add_text; no icon is shown when nothing is returned]
    hook.Run('ChatboxGetPlayerIcon', actor, text, team_chat) or {},
    --- Provides the color of the name of a player in what they say. Called on the server by
    -- `Chatbox.player_say`. The Chatbox plugin's own handler supplies the team color.
    -- @param actor [Player the speaker]
    -- @param text [String the message]
    -- @param team_chat [Boolean whether the message is meant for the team chat]
    -- @return [Color color of the name; the color of the speaker's team when nothing is
    --   returned]
    hook.Run('ChatboxGetPlayerColor', actor, text, team_chat) or team.GetColor(actor:Team()),
    actor,
    --- Provides the color of the text of what a player says. Called on the server by
    -- `Chatbox.player_say`. The Chatbox plugin's own handler supplies white.
    -- @param actor [Player the speaker]
    -- @param text [String the message]
    -- @param team_chat [Boolean whether the message is meant for the team chat]
    -- @return [Color color of the text; white when nothing is returned]
    hook.Run('ChatboxGetMessageColor', actor, text, team_chat) or Color(255, 255, 255),
    ': ',
    text,
    { sender = actor }
  }

  --- Lets plugins alter or replace the message a player is about to say. Called on the server
  -- by `Chatbox.player_say` once the default message has been put together, before it is
  -- passed to `Chatbox.add_text`.
  -- @param actor [Player the speaker]
  -- @param text [String the text being said, without surrounding whitespace]
  -- @param message [List arguments for Chatbox.add_text: the icon, the name color, the
  --   speaker, the text color, ': ', the text and the options table; modify it in place]
  hook.Run('ChatboxAdjustPlayerSay', actor, text, message)

  Chatbox.add_text(nil, unpack(message))
end

Cable.receive('fl_chat_text_add', function(actor, ...)
  if !IsValid(actor) then return end

  Chatbox.set_client_mode(true)
  Chatbox.add_text(actor, ...)
  Chatbox.set_client_mode(false)
end)

Cable.receive('fl_chat_player_say', function(actor, text, team_chat)
  Chatbox.player_say(actor, text, team_chat)
end)
