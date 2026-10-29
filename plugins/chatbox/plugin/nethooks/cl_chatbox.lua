--- Client-side receiver of the Chatbox plugin: the messages that the server sends, which are
-- added to the chatbox.

Cable.receive('fl_chat_message_add', function(message_data)
  Chatbox.add_message(message_data)
end)
