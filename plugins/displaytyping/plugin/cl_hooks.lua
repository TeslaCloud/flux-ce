--- Client-side hooks of the Display Typing plugin: follows the chatbox of the local player,
-- receives the typing of the players nearby from the server and draws their bubbles.

--- Reports the text the local player is typing in the chatbox. The chatbox runs this with
-- an empty string when it closes, which is also what happens after a message is sent, and
-- that ends the typing.
-- @param new_text [String current contents of the chat text entry]
function DisplayTyping:ChatTextChanged(new_text)
  self:report(new_text)
end

--- Has the look of the bubbles read from the theme again once it has been loaded.
-- @param current_theme [ThemeBase]
function DisplayTyping:OnThemeLoaded(current_theme)
  self:invalidate_metrics()
end

--- Has the sizes of the bubbles worked out again for the new size of the screen.
-- @param old_width [Number previous screen width]
-- @param old_height [Number previous screen height]
-- @param new_width [Number new screen width]
-- @param new_height [Number new screen height]
function DisplayTyping:OnScreenSizeChanged(old_width, old_height, new_width, new_height)
  self:invalidate_metrics()
end

--- Has the bubbles show or hide the live text when the local player switches the setting.
-- @param id [String setting id]
-- @param value [Any new value of the setting]
-- @param old_value [Any previous value of the setting]
function DisplayTyping:ClientSettingChanged(id, value, old_value)
  if id == 'display_typing_live_text' then
    self:invalidate_metrics()
  end
end

--- Has the bubbles show or hide the live text when the server switches the
-- 'display_exact_message' config.
-- @param key [String config key]
-- @param old_value [Any value the client had before]
-- @param new_value [Any value that has been received]
function DisplayTyping:OnConfigReceived(key, old_value, new_value)
  if key == 'display_exact_message' then
    self:invalidate_metrics()
  end
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
