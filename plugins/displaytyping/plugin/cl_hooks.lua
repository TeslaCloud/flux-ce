local max_distance = 350 ^ 2

function DisplayTyping:ChatTextChanged(new_text)
  Cable.send('display_typing_text_changed', new_text)
end

function DisplayTyping:HUDPaint()
  if !IsValid(PLAYER) then return end

  local local_pos = PLAYER:EyePos()

  for k, v in ipairs(player.all()) do
    if v == PLAYER then continue end

    local ply_pos = v:EyePos()
    local dist = local_pos:DistToSqr(ply_pos)

    if dist > max_distance or util.vector_obstructed(PLAYER:EyePos(), v:EyePos(), { PLAYER, v }) then continue end

    local text = v:get_nv('chat_text', '')

    if text != '' then
      local text_len = utf8.len(text)

      if text_len >= 48 then
        text = '...'..text:utf8sub(text_len - 45, text_len)
      end

      self:draw_player_typing_text(v, text, ply_pos, dist)
    end
  end
end
