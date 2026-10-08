--- Client-side hooks of the Display Typing plugin: reports the text of the local player to the
-- server and draws the text of the players nearby.

--- Sends the text the local player is typing in the chatbox to the server,
-- which networks it to other players.
-- @param new_text [String current contents of the chat text entry]
function DisplayTyping:ChatTextChanged(new_text)
  Cable.send('display_typing_text_changed', new_text)
end

--- Draws what nearby, unobstructed players are currently typing above their heads.
-- Only the last 45 characters of long texts are shown. How near a player has to be, and
-- whether they are in sight, is decided by `DisplayTyping:draw_player_typing_text`.
function DisplayTyping:HUDPaint()
  if !IsValid(PLAYER) then return end

  local local_pos = PLAYER:EyePos()

  for k, v in player.Iterator() do
    if v == PLAYER then continue end

    local ply_pos = v:EyePos()
    local dist = local_pos:DistToSqr(ply_pos)
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
