--- The quiz screen of the main menu: `fl_quiz`, the fullscreen list of the questions of the
-- entry quiz, `fl_quiz_question`, the card of a single question, and `fl_quiz_option`, one
-- of the answer options on a card.
-- Themes can draw them with the `PaintQuizPanel`, `PaintQuizQuestion` and `PaintQuizOption`
-- methods; a method that returns a value replaces the default look.

local failure_color = Color(255, 110, 110)

--- An answer option of a quiz question (`fl_quiz_option`): a check box and the text of the
-- option, wrapped to the width of the panel. Give it its width first and then its text with
-- `set_option`, which also sets its height. A click on it calls its `on_select` method, if
-- one has been assigned. Derives from `fl_base_panel`.
local PANEL = {}
PANEL.selected = false
PANEL.option_index = 0

--- Sets up the font and the measurements of the option.
function PANEL:Init()
  self.lines = {}
  self.text_font = Theme.get_font('text_small')
  self.line_height = util.font_size(self.text_font)
  self.padding = math.scale(6)
  self.box_size = math.scale(16)
  self.text_x = self.padding * 2 + self.box_size

  self:SetCursor('hand')
end

--- Draws the background of a selected or hovered option, its check box and its text, unless
-- the active theme's PaintQuizOption method does it.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  if Theme.hook('PaintQuizOption', self, w, h) == nil then
    local accent_color = Theme.get_color('accent')
    local text_color = Theme.get_color('text')
    local box_size, padding = self.box_size, self.padding
    local box_y = math.floor(h * 0.5 - box_size * 0.5)
    local text_y = math.floor(h * 0.5 - #self.lines * self.line_height * 0.5)

    if self.selected then
      draw.RoundedBox(0, 0, 0, w, h, accent_color:alpha(80))
    elseif self:IsHovered() then
      draw.RoundedBox(0, 0, 0, w, h, Theme.get_color('background_light'):alpha(200))
    end

    surface.SetDrawColor(self.selected and accent_color:lighten(40) or text_color:darken(80))
    surface.DrawOutlinedRect(padding, box_y, box_size, box_size)

    if self.selected then
      local inset = math.max(math.floor(box_size * 0.25), 2)

      surface.DrawRect(padding + inset, box_y + inset, box_size - inset * 2, box_size - inset * 2)
    end

    for k, v in ipairs(self.lines) do
      draw.SimpleText(v, self.text_font, self.text_x, text_y + (k - 1) * self.line_height, text_color)
    end
  end
end

--- Calls the on_select method of the option on a left click.
-- @param key [Number mouse button code, one of the MOUSE_ enums]
function PANEL:OnMousePressed(key)
  if key == MOUSE_LEFT and self.on_select then
    surface.PlaySound(Theme.get_sound('button_click_success_sound', 'garrysmod/ui_click.wav'))

    self:on_select()
  end
end

--- Sets the text of the option and resizes the panel to the height the text takes up at the
-- current width of the panel.
-- @param index [Number position of the option among the options of its question]
-- @param text [String text or language phrase]
function PANEL:set_option(index, text)
  local translated = t(text)

  self.option_index = index
  self.lines = util.wrap_text(translated, self.text_font, self:GetWide() - self.text_x - self.padding) or {}

  self:SetTall(math.max(#self.lines * self.line_height, self.box_size) + self.padding * 2)
end

--- Returns the position of the option among the options of its question.
-- @return [Number]
function PANEL:get_option_index()
  return self.option_index
end

--- Sets whether the option is drawn as the chosen one.
-- @param selected [Boolean]
function PANEL:set_selected(selected)
  self.selected = selected == true
end

--- Checks whether the option is drawn as the chosen one.
-- @return [Boolean]
function PANEL:is_selected()
  return self.selected
end

vgui.Register('fl_quiz_option', PANEL, 'fl_base_panel')

--- The card of one question of the quiz (`fl_quiz_question`): the numbered text of the
-- question and an `fl_quiz_option` for each of its options, of which the player picks one.
-- Give it its width first and then the question with `set_question`, which also sets its
-- height. When the player picks an option, its `on_answer` method is called with the
-- position of the option, if one has been assigned. Derives from `fl_base_panel`.
local PANEL = {}
PANEL.question = false
PANEL.selected = false

--- Sets up the font and the measurements of the card.
function PANEL:Init()
  self.lines = {}
  self.options = {}
  self.text_font = Theme.get_font('text_normal')
  self.line_height = util.font_size(self.text_font)
  self.padding = math.scale(12)
end

--- Draws the background of the card and the text of the question, unless the active theme's
-- PaintQuizQuestion method does it.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  if Theme.hook('PaintQuizQuestion', self, w, h) == nil then
    local text_color = Theme.get_color('text')
    local padding = self.padding

    draw.RoundedBox(0, 0, 0, w, h, Theme.get_color('background'):alpha(200))

    for k, v in ipairs(self.lines) do
      draw.SimpleText(v, self.text_font, padding, padding + (k - 1) * self.line_height, text_color)
    end
  end
end

--- Sets the question of the card: wraps its text to the current width of the card, creates
-- the options below it and resizes the card to fit them. No option is chosen afterward.
-- @param number [Number number shown in front of the question]
-- @param question [Map the question as the server sends it: id, text and options]
function PANEL:set_question(number, question)
  local padding = self.padding
  local inner_width = self:GetWide() - padding * 2
  local gap = math.scale(2)
  local text = number..'. '..t(question.text)

  for k, v in ipairs(self.options) do
    if IsValid(v) then
      v:safe_remove()
    end
  end

  self.question = question
  self.selected = false
  self.options = {}
  self.lines = util.wrap_text(text, self.text_font, inner_width) or {}

  local cur_y = padding + #self.lines * self.line_height + math.scale(8)

  for k, v in ipairs(question.options) do
    local option = vgui.Create('fl_quiz_option', self)
    option:SetPos(padding, cur_y)
    option:SetWide(inner_width)
    option:set_option(k, tostring(v))
    option.on_select = function(pnl)
      self:select_option(k)
    end

    cur_y = cur_y + option:GetTall() + gap

    table.insert(self.options, option)
  end

  self:SetTall(cur_y - gap + padding)
end

--- Returns the question of the card.
-- @return [Map the question, or false if none has been set]
function PANEL:get_question()
  return self.question
end

--- Makes an option the chosen one, in place of the option that was chosen before, and calls
-- the on_answer method of the card.
-- @param index [Number position of the option]
function PANEL:select_option(index)
  if !IsValid(self.options[index]) then return end

  self.selected = index

  for k, v in ipairs(self.options) do
    v:set_selected(k == index)
  end

  if self.on_answer then
    self:on_answer(index)
  end
end

--- Returns the option the player has chosen.
-- @return [Number position of the chosen option, or false if none is chosen yet]
function PANEL:get_selected()
  return self.selected
end

vgui.Register('fl_quiz_question', PANEL, 'fl_base_panel')

--- The quiz screen (`fl_quiz`): a fullscreen submenu of the main menu with the title of the
-- quiz, a few lines that tell the player what is asked of them, a scrollable list with an
-- `fl_quiz_question` for every question and the buttons that hand the answers in and leave.
-- The plugin opens it with `Quiz:open_panel` and fills it with `set_quiz`. The server grades
-- the answers; the screen only shows whether the attempt has failed and how long the player
-- has to wait before the next one. The leave button disconnects, or closes the main menu
-- for a player who has a character loaded. Derives from `fl_base_panel`.
local PANEL = {}
PANEL.message = ''
PANEL.status_text = ''

--- Covers the screen and creates the list of questions and the two buttons.
function PANEL:Init()
  local scrw, scrh = ScrW(), ScrH()
  local button_w = math.floor(scrw * 0.125)
  local button_h = Theme.get_option('menu_sidebar_button_height', math.scale(42))
  local font = Theme.get_font('main_menu_normal')
  local icon_size = math.scale(16)

  self:SetPos(0, 0)
  self:SetSize(scrw, scrh)

  self.cards = {}
  self.questions = {}
  self.info = {}
  self.intro_lines = {}
  self.can_go_back = IsValid(PLAYER) and PLAYER:is_character_loaded() and !PLAYER:is_character_banned()

  self.scroll_panel = vgui.Create('DScrollPanel', self)

  self.leave_button = vgui.Create('fl_button', self)
  self.leave_button:SetSize(button_w, button_h)
  self.leave_button:SetFont(font)
  self.leave_button:SetTitle(self.can_go_back and t'ui.quiz.back' or t'ui.quiz.disconnect')
  self.leave_button:SetDrawBackground(false)
  self.leave_button:set_icon('fa-chevron-left')
  self.leave_button:set_icon_size(icon_size)
  self.leave_button:set_centered(true)
  self.leave_button.DoClick = function(btn)
    surface.PlaySound(Theme.get_sound('button_click_success_sound', 'garrysmod/ui_click.wav'))

    self:leave()
  end

  self.submit_button = vgui.Create('fl_button', self)
  self.submit_button:SetSize(button_w, button_h)
  self.submit_button:SetFont(font)
  self.submit_button:SetTitle(t'ui.quiz.submit')
  self.submit_button:SetDrawBackground(false)
  self.submit_button:set_icon('fa-chevron-right', true)
  self.submit_button:set_icon_size(icon_size)
  self.submit_button:set_centered(true)
  self.submit_button.DoClick = function(btn)
    surface.PlaySound(Theme.get_sound('button_click_success_sound', 'garrysmod/ui_click.wav'))

    self:submit()
  end

  self:layout()
end

--- Draws the title, the introduction and the status line of the quiz, unless the active
-- theme's PaintQuizPanel method does it. The background is that of the main menu.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  if Theme.hook('PaintQuizPanel', self, w, h) == nil then
    local title = t'ui.quiz.title'
    local title_font = Theme.get_font('main_menu_title')
    local text_font = Theme.get_font('main_menu_normal')
    local text_color = Theme.get_color('text')
    local line_height = util.font_size(text_font)
    local center_x = w * 0.5

    draw.SimpleText(title, title_font, center_x, h / 8, text_color, TEXT_ALIGN_CENTER)

    for k, v in ipairs(self.intro_lines) do
      draw.SimpleText(
        v,
        text_font,
        center_x,
        self.intro_y + (k - 1) * line_height,
        text_color,
        TEXT_ALIGN_CENTER
      )
    end

    if self.status_text != '' then
      draw.SimpleText(self.status_text, text_font, center_x, self.status_y, failure_color, TEXT_ALIGN_CENTER)
    end
  end
end

--- Updates the status line and the submit button four times a second, which keeps the
-- countdown to the next attempt running.
function PANEL:Think()
  self.BaseClass.Think(self)

  local cur_time = CurTime()

  if self.next_update and self.next_update > cur_time then return end

  self.next_update = cur_time + 0.25

  self:update_status()
end

--- Removes the screen and then calls the callback, as the main menu expects of a submenu.
-- While a quiz is pending the screen stays where it is and the callback is not called, so
-- that no other submenu can take its place.
-- @param callback=nil [Function called without arguments]
function PANEL:close(callback)
  if Quiz:is_pending() then return end

  self:safe_remove()

  if callback then
    callback()
  end
end

--- Builds the introduction from what the server has said about the quiz: the share of
-- correct answers that is required and what happens to a player who fails.
-- @return [String]
function PANEL:get_intro_text()
  local info = self.info
  local percentage = tonumber(info.percentage) or 100
  local delay = tonumber(info.delay) or 0
  local parts = { (t'ui.quiz.intro') }

  if percentage < 100 then
    table.insert(parts, (t('ui.quiz.required', { percent = percentage })))
  else
    table.insert(parts, (t'ui.quiz.required_all'))
  end

  if info.kick then
    table.insert(parts, (t'ui.quiz.fail_kick'))
  elseif delay > 0 then
    table.insert(parts, (t('ui.quiz.fail_retry', { time = Flux.Lang:duration(delay) })))
  end

  return table.concat(parts, ' ')
end

--- Wraps the introduction and places the list, the status line and the buttons below it:
-- the list takes the middle half of the screen from the introduction down to three quarters
-- of the height of the screen.
function PANEL:layout()
  local w, h = self:GetSize()
  local text_font = Theme.get_font('main_menu_normal')
  local title_h = util.text_height(t'ui.quiz.title', Theme.get_font('main_menu_title'))
  local button_h = self.leave_button:GetTall()
  local margin = math.scale(8)
  local list_w, list_x = math.floor(w * 0.5), math.floor(w * 0.25)
  local list_bottom = math.floor(h * 0.75)
  local lines = util.wrap_text(self:get_intro_text(), text_font, list_w) or {}

  for k, v in ipairs(lines) do
    lines[k] = string.Trim(v)
  end

  self.intro_lines = lines
  self.intro_y = math.floor(h / 8) + title_h + margin

  local list_y = self.intro_y + #lines * util.font_size(text_font) + margin * 2

  self.scroll_panel:SetPos(list_x, list_y)
  self.scroll_panel:SetSize(list_w, math.max(list_bottom - list_y, 0))

  self.status_y = list_bottom + margin

  self.leave_button:SetPos(list_x, list_bottom + button_h)
  self.submit_button:SetPos(list_x + list_w - self.submit_button:GetWide(), list_bottom + button_h)
end

--- Recreates the cards of the questions. The answers the player has chosen are lost.
function PANEL:rebuild()
  local card_w = self.scroll_panel:GetWide() - math.max(math.scale(20), 18)
  local margin = math.scale(8)
  local cur_y = 0

  self.scroll_panel:Clear()
  self.cards = {}

  for k, v in ipairs(self.questions) do
    if istable(v) and isstring(v.id) and isstring(v.text) and istable(v.options) then
      local card = vgui.Create('fl_quiz_question', self)
      card:SetPos(0, cur_y)
      card:SetWide(card_w)
      card:set_question(#self.cards + 1, v)
      card.on_answer = function(pnl, index)
        self:set_message('')
      end

      self.scroll_panel:AddItem(card)

      cur_y = cur_y + card:GetTall() + margin

      table.insert(self.cards, card)
    end
  end

  self.scroll_panel:InvalidateLayout()
end

--- Shows a quiz: stores what the server has sent, lays the screen out and creates a card
-- for every question.
-- @param questions [List<Map> the questions, each with the id, text and options fields]
-- @param info [Map what the server says about the quiz: signature (String), percentage
--   (Number share of correct answers required), kick (Boolean whether failing kicks), delay
--   (Number seconds between attempts) and wait (Number seconds until the next attempt)]
function PANEL:set_quiz(questions, info)
  self.questions = istable(questions) and questions or {}
  self.info = istable(info) and info or {}
  self.message = ''
  self.submitted_at = nil

  self:layout()
  self:rebuild()
  self:update_status()
end

--- Updates what the screen says about the quiz without touching the questions and the
-- answers the player has chosen.
-- @param info [Map what the server says about the quiz, see `set_quiz`]
function PANEL:set_info(info)
  self.info = istable(info) and info or {}

  self:layout()
  self:update_status()
end

--- Returns the answers the player has chosen so far.
-- @return [Map position of the chosen option by question ID]
function PANEL:get_answers()
  local answers = {}

  for k, v in ipairs(self.cards) do
    local selected = v:get_selected()

    if selected then
      answers[v:get_question().id] = selected
    end
  end

  return answers
end

--- Sets the message shown in the status line, in front of the countdown to the next attempt.
-- @param message [String translated text, or an empty string for none]
function PANEL:set_message(message)
  self.message = message

  self:update_status()
end

--- Puts the status line together from the message and the wait for the next attempt, and
-- enables the submit button only while the player may hand their answers in: not during
-- that wait, and not while the server has yet to answer the previous attempt, which is
-- given up on after five seconds.
function PANEL:update_status()
  local wait = Quiz:get_retry_wait()
  local text = self.message

  if self.submitted_at and CurTime() - self.submitted_at > 5 then
    self.submitted_at = nil
  end

  if wait > 0 then
    local retry_text = t('ui.quiz.retry_in', { time = Flux.Lang:duration(math.ceil(wait)) })

    text = text != '' and text..' '..retry_text or retry_text
  end

  self.status_text = text

  local can_submit = wait <= 0 and !self.submitted_at

  if can_submit != self.can_submit then
    self.can_submit = can_submit

    self.submit_button:set_enabled(can_submit)
  end
end

--- Hands the answers in to the server. When a question has no answer yet, the list scrolls
-- to it and the player is told to answer every question instead.
function PANEL:submit()
  if self.submitted_at or Quiz:get_retry_wait() > 0 then return end

  for k, v in ipairs(self.cards) do
    if !v:get_selected() then
      self.scroll_panel:ScrollToChild(v)

      self:set_message((t'ui.quiz.incomplete'))

      return
    end
  end

  self.submitted_at = CurTime()

  self:set_message('')

  Quiz:submit(self:get_answers())
end

--- Shows the outcome of an attempt that did not pass.
-- @param graded [Boolean true when the answers were graded and found wanting, false when
--   they were not looked at because the player has to wait]
function PANEL:show_result(graded)
  self.submitted_at = nil

  self:set_message(graded and t'ui.quiz.failed' or '')
end

--- Leaves the quiz: closes the main menu for a player who has a character loaded, and asks
-- everyone else whether they want to disconnect.
function PANEL:leave()
  if self.can_go_back then
    local menu = self:GetParent()

    if IsValid(menu) then
      menu:safe_remove()
    end

    return
  end

  local message, title = t'ui.main_menu.disconnect_msg', t'ui.main_menu.disconnect'
  local yes, no = t'ui.yes', t'ui.no'

  Derma_Query(message, title, yes, function()
    RunConsoleCommand('disconnect')
  end, no)
end

vgui.Register('fl_quiz', PANEL, 'fl_base_panel')
