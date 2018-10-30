function Chatbox:ChatboxGetPlayerIcon(player, text, team_chat)
  return { image = 'materials/icon16/shield.png', width = 16, height = 16, is_data = true }
end

function Chatbox:ChatboxGetPlayerColor(player, text, team_chat)
  return _team.GetColor(player:Team()) or Color(255, 255, 255)
end

function Chatbox:ChatboxGetMessageColor(player, text, team_chat)
  return Color(255, 255, 255)
end
