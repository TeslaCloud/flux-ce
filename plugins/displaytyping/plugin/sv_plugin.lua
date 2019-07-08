Cable.receive('display_typing_text_changed', function(player, new_text)
  if IsValid(player) then
    player:set_nv('chat_text', new_text)
  end
end)
