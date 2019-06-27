local max_distance = 512 ^ 2

function DisplayTyping:ChatTextChanged(new_text)
  Cable.send('display_typing_text_changed', new_text)
end

function DisplayTyping:HUDPaint()
  if !IsValid(PLAYER) then return end

  local local_pos = PLAYER:GetPos()

  for k, v in ipairs(player.all()) do
    if v == PLAYER then continue end

    local ply_pos = v:GetPos()
    local dist = local_pos:DistToSqr(ply_pos)

    if dist > max_distance then continue end

    local text = v:get_nv('chat_text', '')

    if text != '' then
      local tl = utf8.len(text)

      if tl >= 48 then
        text = '...'..text:utf8sub(tl - 45, tl)
      end

      self:draw_player_typing_text(v, text, ply_pos, dist)
    end
  end
end

function DisplayTyping:DrawPlayerTargetID(player)
  if IsValid(player) and IsValid(PLAYER) and player:get_nv('chat_text', '') != '' then
    local tr = PLAYER:GetEyeTraceNoCursor()

    if tr.Entity != player then
      return false
    end
  end
end

function DisplayTyping:DisplayTypingTextType(player, text)
  if text:starts('/me') then
    return t'display_typing.performing'
  elseif text:starts('/w') then
    return t'display_typing.whispering'
  elseif text:starts('/y') then
    return t'display_typing.yelling'
  elseif !text:is_command() then
    return t'display_typing.talking'
  end

  return t'display_typing.typing'
end
