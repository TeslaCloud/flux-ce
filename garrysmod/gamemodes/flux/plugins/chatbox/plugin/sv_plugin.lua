Config.set('chatbox_message_margin', 2)
Config.set('chatbox_message_fade_delay', 12)
Config.set('chatbox_max_messages', 100)

local default_msg_data = {
  sender = nil,
  listeners = {},
  data = {},
  position = nil,
  radius = 0,
  filter = nil,
  rich = false,
  size = 20,
  text = nil,
  team_chat = false
}

local filters = {}
local client_mode = false

function chatbox.add_filter(id, data)
  filters[id] = data
end

function chatbox.can_hear(listener, message_data)
  if plugin.call('PlayerCanHear', listener, message_data) then
    return true
  end

  if IsValid(listener) and listener:has_initialized() then
    local position, radius = message_data.position, message_data.radius

    if !isnumber(radius) then return false end
    if radius == 0 then return true end
    if radius < 0 then return false end

    if istable(position) then
      for k, v in pairs(position) do
        if v:Distance(listener:GetPos()) <= radius then
          return true
        end
      end
    end

    if position:Distance(listener:GetPos()) <= radius then
      return true
    end
  end

  return false
end

function chatbox.add_text(listeners, ...)
  local message_data = {
    sender = nil,
    listeners = listeners or {},
    data = {},
    position = nil,
    radius = 0,
    filter = nil,
    rich = false,
    size = 20,
    text = nil,
    team_chat = false
  }

  if !istable(listeners) then
    if IsValid(listeners) then
      listeners = { listeners }
    else
      listeners = _player.GetAll()
    end
  end

  -- Compile the initial message data table.
  for k, v in ipairs({...}) do
    if isstring(v) then
      table.insert(message_data.data, v)

      if k == 1 then
        message_data.text = v
      end
    elseif isnumber(v) then
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

  for k, v in ipairs(listeners) do
    local data = message_data

    hook.run('AdjustMessageData', v, data)

    if chatbox.can_hear(v, data) then
      Cable.send(v, 'fl_chat_message_add', data)
    end
  end
end

function chatbox.set_client_mode(val)
  client_mode = val
end

function chatbox.message_to_string(message_data, concatenator)
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

Cable.receive('fl_chat_text_add', function(player, ...)
  if !IsValid(player) then return end

  chatbox.set_client_mode(true)
  chatbox.add_text(player, ...)
  chatbox.set_client_mode(false)
end)

Cable.receive('fl_chat_player_say', function(player, text, team_chat)
  if !IsValid(player) then return end

  local player_say_override = hook.run('PlayerSay', player, text, team_chat)

  if isstring(player_say_override) then
    if player_say_override == '' then return end

    text = player_say_override
  end

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

  chatbox.add_text(nil, unpack(message))
end)
