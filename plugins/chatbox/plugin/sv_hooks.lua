function Chatbox:ChatboxGetPlayerIcon(player, text, team_chat)
  return { icon = 'fa-shield-alt', size = 14, margin = 8, is_data = true }
end

function Chatbox:ChatboxGetPlayerColor(player, text, team_chat)
  return _team.GetColor(player:Team()) or Color(255, 255, 255)
end

function Chatbox:ChatboxGetMessageColor(player, text, team_chat)
  return Color(255, 255, 255)
end

function Chatbox:PlayerCanHear(player, message_data)
  if player == message_data.sender then
    return true
  end
end
