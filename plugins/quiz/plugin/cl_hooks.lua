--- Client-side hooks of the Quiz plugin: registers the quiz screen with the theme, puts it
-- into the main menu while a quiz is pending and supplies the error text for a character
-- that the server refused to create because of the quiz.

--- Registers the 'quiz' panel with the theme, and opens the quiz screen again when the main
-- menu was recreated for the theme while a quiz is pending.
-- @param current_theme [ThemeBase]
function Quiz:OnThemeLoaded(current_theme)
  current_theme:add_panel('quiz', function(id, parent, ...)
    return vgui.Create('fl_quiz', parent)
  end)

  self:open_panel()
end

--- Opens the quiz screen in the main menu whenever the menu fills its sidebar while a quiz
-- is pending, which hides the buttons that the other plugins have just added.
-- @param panel [Panel the main menu]
-- @param sidebar [Panel the main menu sidebar]
function Quiz:AddMainMenuItems(panel, sidebar)
  self:open_panel(panel)
end

--- Supplies the error text shown when character creation fails because the quiz has not
-- been passed.
-- @param success [Boolean]
-- @param status [Number CHAR_* status code sent by the server]
-- @return [String translated error for CHAR_ERR_QUIZ, otherwise nil]
function Quiz:GetCharCreationErrorText(success, status)
  if status == CHAR_ERR_QUIZ then
    return t'error.quiz.not_passed'
  end
end
