--- Client-side receivers of the Display Typing plugin: the typing of the players nearby,
-- which updates and removes their bubbles.

Cable.receive('fl_typing_update', function(index, text, exact)
  DisplayTyping:update_bubble(index, text, exact)
end)

Cable.receive('fl_typing_stop', function(index)
  DisplayTyping:stop_bubble(index)
end)
