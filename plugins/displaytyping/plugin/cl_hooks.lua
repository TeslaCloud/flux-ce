--- Client-side hooks of the Display Typing plugin: follows the chatbox of the local player,
-- receives the typing of the players nearby from the server and draws their bubbles.

--- Reports the text the local player is typing in the chatbox. The chatbox runs this with
-- an empty string when it closes, which is also what happens after a message is sent, and
-- that ends the typing.
-- @param new_text [String current contents of the chat text entry]
function DisplayTyping:ChatTextChanged(new_text)
  self:report(new_text)
end

--- Draws the typing bubbles, unless the HUD is hidden.
function DisplayTyping:HUDPaint()
  if !IsValid(PLAYER) or !PLAYER:has_initialized() or !Theme.initialized() then return end

  --- Flux's `ShouldHUDPaint` hook, asked again here before the typing bubbles are drawn, so
  -- that whatever hides the HUD hides the bubbles as well. Called on the client on every HUD
  -- paint once the local player has been initialized.
  -- @return [Boolean Return false to hide the HUD and the typing bubbles with it]
  if hook.Run('ShouldHUDPaint') == false then return end

  self:draw_bubbles()
end

Cable.receive('fl_typing_update', function(index, text, exact)
  DisplayTyping:update_bubble(index, text, exact)
end)

Cable.receive('fl_typing_stop', function(index)
  DisplayTyping:stop_bubble(index)
end)
