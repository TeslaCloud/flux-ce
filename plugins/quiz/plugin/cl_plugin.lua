--- Client side of the Quiz plugin: remembers the quiz the server has sent, opens and closes
-- the quiz screen and hands the answers of the player in.
-- While a quiz is pending, the quiz screen takes the place of the buttons of the main menu:
-- it becomes the submenu of the menu, and the sidebar is hidden until the player has passed.
-- The client never learns which answers are correct; the server grades them and only says
-- whether the player has passed and how long they have to wait before the next attempt.

Quiz.pending = Quiz.pending or false
Quiz.pending_questions = Quiz.pending_questions or {}
Quiz.pending_info = Quiz.pending_info or {}

--- Checks whether the local player still has to pass a quiz that the server has sent.
-- @return [Boolean]
function Quiz:is_pending()
  return self.pending == true
end

--- Returns how long the local player has to wait before they may hand in their answers
-- again.
-- @return [Number seconds, 0 when they may hand them in now]
function Quiz:get_retry_wait()
  return math.max((self.retry_at or 0) - CurTime(), 0)
end

--- Returns the quiz screen while it is open.
-- @return [Panel the quiz screen, or nil]
function Quiz:get_panel()
  if IsValid(self.panel) then
    return self.panel
  end
end

--- Opens the quiz screen in the main menu, if a quiz is pending and the menu is open. The
-- screen is created through the 'quiz' panel of the theme and becomes the submenu of the
-- menu; a submenu that is open is closed, and the sidebar of the menu is hidden. When the
-- screen is already open in that menu it is only brought to the front.
-- @param menu=Flux.intro_panel [Panel the main menu to open the screen in]
-- @return [Panel the quiz screen, or nil when it was not opened]
function Quiz:open_panel(menu)
  menu = menu or Flux.intro_panel

  if !self.pending or !IsValid(menu) or !isfunction(menu.RecreateSidebar) then return end

  local panel = self:get_panel()

  if panel and panel:GetParent() != menu then
    panel:safe_remove()

    panel = nil
  end

  if !panel then
    panel = Theme.create_panel('quiz', menu)

    if !IsValid(panel) then
      panel = vgui.Create('fl_quiz', menu)
    end

    if isfunction(panel.set_quiz) then
      panel:set_quiz(self.pending_questions, self.pending_info)
    end

    self.panel = panel
  end

  if IsValid(menu.menu) and menu.menu != panel then
    menu.menu:safe_remove()
  end

  menu.menu = panel

  if IsValid(menu.sidebar) then
    menu.sidebar:SetVisible(false)
  end

  panel:MoveToFront()

  return panel
end

--- Closes the quiz screen. When it is the submenu of the main menu, the menu slides it away
-- and brings its buttons back.
function Quiz:close_panel()
  local panel = self:get_panel()

  self.panel = nil

  if !panel then return end

  local menu = panel:GetParent()

  if IsValid(menu) and menu.menu == panel and isfunction(menu.to_main_menu) then
    menu:to_main_menu()
  else
    panel:safe_remove()
  end
end

--- Hands the answers of the local player in to the server, which grades them. Does nothing
-- when no quiz is pending.
-- @param answers [Map position of the chosen option by question ID]
function Quiz:submit(answers)
  if !self.pending or !istable(answers) then return end

  Cable.send('fl_quiz_submit', answers)
end

Cable.receive('fl_quiz_open', function(questions, info)
  if !istable(questions) or !istable(info) then return end

  local panel = Quiz:get_panel()
  local unchanged = Quiz.pending and Quiz.pending_info.signature == info.signature

  Quiz.pending = true
  Quiz.pending_questions = questions
  Quiz.pending_info = info
  Quiz.retry_at = CurTime() + math.max(tonumber(info.wait) or 0, 0)

  if panel and !unchanged and isfunction(panel.set_quiz) then
    panel:set_quiz(questions, info)
  elseif panel and isfunction(panel.set_info) then
    panel:set_info(info)
  end

  Quiz:open_panel()
end)

Cable.receive('fl_quiz_close', function()
  Quiz.pending = false
  Quiz.retry_at = nil

  Quiz:close_panel()
end)

Cable.receive('fl_quiz_result', function(passed, wait, graded)
  if passed then
    local menu = Flux.intro_panel
    local text = t'ui.quiz.passed'

    Quiz.pending = false
    Quiz.retry_at = nil

    Quiz:close_panel()

    if IsValid(menu) and isfunction(menu.notify) then
      menu:notify(text)
    end

    return
  end

  local panel = Quiz:get_panel()

  Quiz.retry_at = CurTime() + math.max(tonumber(wait) or 0, 0)

  if panel and isfunction(panel.show_result) then
    panel:show_result(graded == true)
  end
end)
