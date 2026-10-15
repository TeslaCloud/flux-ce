--- The chatbox panel (`fl_chat_panel`): a scrolling history of message panels above a text
-- entry.
-- While it is closed only recent messages are visible until they fade out. While it is open
-- the whole history is shown and the text entry takes the input, with a history of earlier
-- entries on the up and down keys. While a command is typed, the suggestions of
-- `Flux.Command:complete` for the text up to the caret are listed above the entry along with
-- the name, syntax and description of the command: Tab puts the selected suggestion in place
-- of the word that is typed, and pressing it again replaces that with the next suggestion
-- (Shift+Tab goes back); the up and down keys move the selection while there are
-- suggestions. Enter sends the text as it is typed. The state of the suggestions is kept on
-- the panel for themes that draw them through the ChatboxPaintOver hook: `completion` (the
-- result of `Flux.Command:complete`, nil while no command is typed), `completion_index` (the
-- selected suggestion), `completion_offset` (how many suggestions are scrolled past) and
-- `completion_prefix` (the command prefix that was typed).
-- `Chatbox.create` creates the panel and keeps it in Chatbox.panel.

local get_option, get_font, get_color = Theme.get_option, Theme.get_font, Theme.get_color
local config_get = Config.get
local simple_text_outlined = draw.SimpleTextOutlined
local outline_color = Color(0, 0, 0, 120)
local max_rows = 8

--- Cuts a text after a number of characters.
-- @param text [String]
-- @param count [Number how many characters to keep]
-- @return [String the first characters of the text, or all of it if it is shorter]
local function cut_chars(text, count)
  if count <= 0 then return '' end

  local byte = utf8.offset(text, count + 1)

  if !byte then return text end

  return text:sub(1, byte - 1)
end

--- Counts the characters of a text, or its bytes if it is not valid UTF-8.
-- @param text [String]
-- @return [Number]
local function char_len(text)
  return utf8.len(text) or #text
end

--- Moves a position in a list by a step, wrapping around at both ends.
-- @param index [Number current position]
-- @param count [Number length of the list]
-- @param step [Number how far to move, negative to move back]
-- @return [Number the new position]
local function wrap_index(index, count, step)
  return (index - 1 + step) % count + 1
end

--- Works out how many suggestions to scroll past so that the selected one is visible.
-- @param offset [Number how many suggestions are scrolled past now]
-- @param index [Number position of the selected suggestion, nil if none is selected]
-- @param count [Number how many suggestions there are]
-- @param rows [Number how many of them are visible at once]
-- @return [Number the new offset]
local function scroll_offset(offset, index, count, rows)
  offset = offset or 0

  if index then
    if index <= offset then
      offset = index - 1
    elseif index > offset + rows then
      offset = index - rows
    end
  end

  return math.max(0, math.min(offset, count - rows))
end

--- Splits the syntax of a command into the arguments in angle or square brackets and the
-- text between them.
-- @param syntax [String]
-- @return [List<Map> segments: text (String) and arg (Number position of the argument, nil
--   for the text between arguments), Number how many arguments there are]
local function split_syntax(syntax)
  local segments = {}
  local depth, start, arg = 0, 1, 0

  for i = 1, #syntax do
    local char = syntax:sub(i, i)

    if char == '<' or char == '[' then
      if depth == 0 then
        if i > start then
          segments[#segments + 1] = { text = syntax:sub(start, i - 1) }
        end

        start = i
      end

      depth = depth + 1
    elseif (char == '>' or char == ']') and depth > 0 then
      depth = depth - 1

      if depth == 0 then
        arg = arg + 1
        segments[#segments + 1] = { text = syntax:sub(start, i), arg = arg }
        start = i + 1
      end
    end
  end

  if start <= #syntax then
    segments[#segments + 1] = { text = syntax:sub(start) }
  end

  return segments, arg
end

--- Picks the argument of the syntax to emphasise: the one that is typed, or the last one
-- while further words are typed for a 'text' argument that takes the rest of the text.
-- @param arg_index [Number position of the argument that is typed, nil if none is]
-- @param arg_type [String/List<String> its type]
-- @param arg_count [Number how many arguments the syntax lists]
-- @return [Number position of the argument in the syntax, nil if none fits]
local function emphasised_arg(arg_index, arg_type, arg_count)
  if !arg_index or arg_count < 1 then return end

  if arg_index <= arg_count then
    return arg_index
  end

  if arg_type == 'text' then
    return arg_count
  end
end

--- Draws an outlined text in the style of the chatbox.
-- @param text [String]
-- @param font [String]
-- @param x [Number]
-- @param y [Number]
-- @param color [Color]
-- @return [Number width of the text, Number height of the text]
local function draw_text(text, font, x, y, color)
  return simple_text_outlined(text, font, x, y, color, nil, nil, 0.5, outline_color)
end

local PANEL = {}
PANEL.history = {}
PANEL.last_pos = 0
PANEL.is_open = false
PANEL.padding = get_option('chatbox_padding', math.scale(8))

--- Creates the scroll panel for the messages and the text entry with its input
-- history, then lays the chatbox out.
function PANEL:Init()
  local w, h = self:GetWide(), self:GetTall()

  self.scroll_panel = vgui.Create('DScrollPanel', self)

  self.scroll_panel.Paint = function() return true end
  self.scroll_panel:GetVBar().Paint = function() return true end
  self.scroll_panel:GetVBar().btnUp.Paint = function() return true end
  self.scroll_panel:GetVBar().btnDown.Paint = function() return true end
  self.scroll_panel:GetVBar().btnGrip.Paint = function() return true end

  self.scroll_panel:GetVBar():SetWide(0)

  -- Keep the messages at the bottom of the history, next to the text entry, while there are
  -- too few of them to fill it. Both layout paths of the scroll panel go through this method.
  local layout = self.scroll_panel.PerformLayoutInternal

  self.scroll_panel.PerformLayoutInternal = function(scroll)
    layout(scroll)

    local canvas = scroll:GetCanvas()
    local free = scroll:GetTall() - canvas:GetTall()

    if free > 0 then
      canvas:SetPos(0, free)
    end
  end

  self.scroll_panel:SetPos(0, 0)
  self.scroll_panel:SetSize(w, h)
  self.scroll_panel:PerformLayout()

  self.text_entry = vgui.Create('fl_text_entry', self)
  self.text_entry:SetText('')
  self.text_entry:SetSize(1, 1)
  self.text_entry:set_limit(config_get('max_message_length', 512))
  self.text_entry.history = {}
  self.text_entry.last_index = 0
  self.text_entry:SetMultiline(true)
  self.text_entry:SetTabbingDisabled(true)

  local allow_input = self.text_entry.AllowInput

  self.text_entry.AllowInput = function(entry, char)
    if char == '\t' then return true end

    return allow_input(entry, char)
  end

  self.text_entry.OnValueChange = function(entry, value)
    local value_w, _value_h = util.text_size(value, entry:GetFont())
    local div = math.round(entry:GetWide() / value_w * 2, 1)
    local offset = div > 2 and 0 or div > 1 and math.scale(25) or math.scale(50)

    self:SetSize(Chatbox.width, Chatbox.height + offset)
    entry:SetTall(get_option('chatbox_text_entry_height', 40) + offset)

    --- The ChatTextChanged hook of GMod, run by the chatbox because it replaces the default
    -- chat. Called on the client whenever the contents of the text entry change, and with an
    -- empty string when the chatbox is closed by `Chatbox.hide`.
    -- @param text [String current contents of the text entry]
    hook.Run('ChatTextChanged', value)
  end

  self.text_entry.OnEnter = function(entry)
    local value = entry:GetValue()

    --- Called on the client when the player presses enter in the chatbox. The handler of the
    -- Chatbox plugin itself sends the text to the server and closes the chatbox.
    -- @param text [String contents of the text entry, which may be empty]
    hook.Run('ChatboxTextEntered', value)

    if entry.history[1] != value then
      table.insert(entry.history, 1, value)

      entry.last_index = 1
    end

    entry:SetText('')
    self:rebuild()
  end

  self.text_entry.OnKeyCodeTyped = function(entry, code)
    local should_set = false

    if code == KEY_ENTER then
      entry:OnEnter()

      return true
    elseif code == KEY_TAB then
      self:insert_completion(input.IsShiftDown() and -1 or 1)

      return true
    elseif (code == KEY_UP or code == KEY_DOWN) and entry:GetValue() != entry.history_value and
           self:move_completion(code == KEY_UP and -1 or 1) then
      return true
    elseif code == KEY_DOWN then
      if entry.last_index == 1 then
        entry.last_index = #entry.history
      else
        entry.last_index = math.Clamp(entry.last_index - 1, 1, #entry.history)
      end

      should_set = true
    elseif code == KEY_UP then
      if entry.last_index == #entry.history then
        entry.last_index = 1
      else
        entry.last_index = math.Clamp(entry.last_index + 1, 1, #entry.history)
      end

      should_set = true
    end

    local history_entry = entry.history[entry.last_index]

    if history_entry and history_entry != '' and should_set then
      entry.history_value = history_entry
      entry:SetText(history_entry)
      entry:SetCaretPos(utf8.len(history_entry))
      entry:OnValueChange(history_entry)

      return true
    end
  end

  self.text_entry.Paint = function(entry, w, h)
    local text_color = get_color('text')
    local border = entry:HasFocus() and get_color('accent') or get_color('border')

    Theme.hook(
      'DrawCard',
      0,
      0,
      w,
      h,
      get_option('corner_radius', math.scale(6)),
      get_color('chat_text_entry_background'),
      border
    )

    entry:DrawTextEntryText(text_color, ColorAlpha(get_color('accent'), 120), text_color)
  end

  self:rebuild()
end

--- Closes the chatbox when escape is pressed and keeps the suggestions up to date with the
-- text entry while it is open. Keeps the messages scrolled to the bottom while the chatbox
-- is closed.
function PANEL:Think()
  if self.is_open then
    if input.IsKeyDown(KEY_ESCAPE) then
      Chatbox.hide()

      if gui.IsGameUIVisible() then
        gui.HideGameUI()
      end
    else
      self:update_completion()
    end
  else
    local vbar = self.scroll_panel:GetVBar()

    vbar:SetScroll(vbar.CanvasSize)
  end
end

--- Draws the background through the ChatboxPaintBackground theme hook
-- while the chatbox is open.
-- @param w [Number]
-- @param h [Number]
function PANEL:Paint(w, h)
  if self.is_open then
    Theme.hook('ChatboxPaintBackground', self, w, h)
  end
end

--- Draws the suggestions for the command that is being typed above the text entry, see
-- `PANEL:draw_completion`. The ChatboxPaintOver theme hook can override this.
-- @param width [Number]
-- @param height [Number]
function PANEL:PaintOver(width, height)
  if Theme.hook('ChatboxPaintOver', self, width, height) == nil and self.completion and
     IsValid(self.text_entry) then
    self:draw_completion(width, height - self.text_entry:GetTall() - math.scale(8))
  end
end

--- Forgets the suggestions, so that they are worked out again for the text entry.
function PANEL:reset_completion()
  self.completion = nil
  self.completion_index = nil
  self.completion_offset = 0
  self.completion_key = nil
  self.completion_list = nil
  self.completion_cycle = nil
end

--- Works out the suggestions for the command in the text entry with `Flux.Command:complete`,
-- for the text between the command prefix and the caret. They are worked out again only
-- once the text or the caret has moved, and stay the ones that are cycled through while Tab
-- cycles through them. The first suggestion is selected whenever the suggestions change.
-- @return [Map the completion result, or nil if no command is being typed]
function PANEL:update_completion()
  local entry = self.text_entry

  if !IsValid(entry) then return end

  local value = entry:GetValue()
  local caret = entry:GetCaretPos()
  local key = caret..':'..value

  if key == self.completion_key then
    return self.completion
  end

  local cycle = self.completion_cycle

  if cycle and cycle.value == value and cycle.caret == caret then
    self.completion_key = key
    self.completion = cycle.result
    self.completion_index = cycle.index

    return self.completion
  end

  self.completion_cycle = nil

  local is_command, prefix_len = string.is_command(value)
  local prefix = is_command and cut_chars(value, prefix_len) or ''
  local before = cut_chars(value, caret)

  if !is_command or #before < #prefix then
    self:reset_completion()
    self.completion_key = key

    return
  end

  local text = before:sub(#prefix + 1)
  local result = Flux.Command:complete(text, PLAYER)
  local list = table.concat(result.candidates, '\n')

  if list != self.completion_list then
    self.completion_list = list
    self.completion_index = #result.candidates > 0 and 1 or nil
    self.completion_offset = 0
  end

  self.completion_key = key
  self.completion = result
  self.completion_prefix = prefix
  self.completion_text = text
  self.completion_after = value:sub(#before + 1)

  return result
end

--- Puts a suggestion in place of the word at the caret, with the caret moved behind it. The
-- first press puts the selected suggestion in. While the text and the caret stay as that
-- left them, every further press replaces it with the next suggestion, or the previous one
-- for a negative step, applied to the text from before the first press. After the only
-- suggestion has been put in, the next press goes on to the word after it.
-- @param step [Number 1 for the next suggestion, -1 for the previous one]
-- @return [Boolean true if a suggestion was put in, nil if there is none]
function PANEL:insert_completion(step)
  local result = self:update_completion()

  if !result or #result.candidates == 0 then return end

  local cycle = self.completion_cycle
  local index

  if cycle then
    index = wrap_index(cycle.index, #result.candidates, step)
  else
    local after = self.completion_after

    if result.start_byte <= #self.completion_text then
      after = after:gsub('^%S+', '')
    end

    cycle = {
      prefix = self.completion_prefix,
      text = self.completion_text,
      after = (after:gsub('^%s+', '')),
      result = result
    }
    index = self.completion_index or 1
  end

  local applied = cycle.prefix..Flux.Command:apply_completion(cycle.text, cycle.result, index)
  local value = applied..cycle.after
  local caret = char_len(applied)
  local entry = self.text_entry

  entry:SetText(value)
  entry:SetCaretPos(caret)
  entry:OnValueChange(value)

  if #cycle.result.candidates > 1 then
    cycle.index = index
    cycle.value = value
    cycle.caret = caret
    self.completion_cycle = cycle
  else
    self.completion_cycle = nil
  end

  self:update_completion()

  return true
end

--- Moves the selection through the suggestions, wrapping around at both ends. While Tab
-- cycles through the suggestions, the newly selected one is put in as Tab does.
-- @param step [Number 1 to move down the list, -1 to move up]
-- @return [Boolean true if there were suggestions to move through, nil otherwise]
function PANEL:move_completion(step)
  local result = self:update_completion()

  if !result or #result.candidates == 0 then return end

  if self.completion_cycle then
    return self:insert_completion(step)
  end

  self.completion_index = wrap_index(self.completion_index or 1, #result.candidates, step)

  return true
end

--- Lays out the card about a command for `PANEL:draw_completion`: its full name, its syntax
-- after the name or on a line of its own if it does not fit there, its description wrapped
-- to the width and its aliases. The layout is kept until the command, its syntax, the
-- emphasised argument or the width change.
-- @param cmd [Command the command or subcommand]
-- @param result [Map the completion result whose typed argument is emphasised in the syntax,
--   nil to emphasise none]
-- @param width [Number width the text may take]
-- @return [Map the layout: name, segments, emphasis, inline, lines, aliases and height]
function PANEL:layout_command_info(cmd, result, width)
  local syntax = t(cmd:get_syntax())
  local segments, arg_count = split_syntax(syntax)
  local emphasis

  if result and syntax != '[-]' then
    emphasis = emphasised_arg(result.arg_index, result.arg_type, arg_count)
  end

  local cached = self.completion_info

  if cached and cached.cmd == cmd and cached.syntax == syntax and cached.emphasis == emphasis and
     cached.width == width then
    return cached
  end

  local font, small_font = get_font('text_normal'), get_font('text_small')
  local font_h, small_h = draw.GetFontHeight(font), draw.GetFontHeight(small_font)
  local name = cmd:get_full_name()
  local inline = util.text_size(name, font) + math.scale(8) + util.text_size(syntax, font) <= width
  local lines = util.wrap_text(t(cmd:get_description() or ''), small_font, width, 0) or {}
  local height = inline and font_h or font_h * 2
  local aliases

  if #lines > 0 then
    height = height + math.scale(4) + #lines * (small_h + math.scale(2))
  end

  if istable(cmd.aliases) and #cmd.aliases > 0 then
    aliases = t'ui.chat.aliases'..': '..table.concat(cmd.aliases, ', ')
    height = height + math.scale(4) + small_h
  end

  self.completion_info = {
    cmd = cmd,
    syntax = syntax,
    width = width,
    name = name,
    segments = segments,
    emphasis = emphasis,
    inline = inline,
    lines = lines,
    aliases = aliases,
    height = height
  }

  return self.completion_info
end

--- Draws the card about a command that `PANEL:layout_command_info` laid out.
-- @param info [Map the layout]
-- @param y [Number top edge of the card]
-- @param width [Number width of the card]
-- @param padding [Number space between the edges of the card and the text]
function PANEL:draw_command_info(info, y, width, padding)
  local font, small_font = get_font('text_normal'), get_font('text_small')
  local font_h = draw.GetFontHeight(font)
  local text_color, muted_color = get_color('text'), get_color('text_muted')
  local radius_small = get_option('corner_radius_small', math.scale(4))
  local emphasis_fill = ColorAlpha(get_color('accent'), 90)

  Theme.hook(
    'DrawCard',
    0,
    y,
    width,
    info.height + padding * 2,
    get_option('corner_radius', math.scale(6)),
    ColorAlpha(get_color('surface'), 240)
  )

  local cur_y = y + padding
  local name_w = draw_text(info.name, font, padding, cur_y, get_color('accent_light'))
  local x = padding + name_w + math.scale(8)

  if !info.inline then
    x = padding
    cur_y = cur_y + font_h
  end

  for _, segment in ipairs(info.segments) do
    local is_emphasised = segment.arg != nil and segment.arg == info.emphasis

    if is_emphasised then
      local segment_w = util.text_size(segment.text, font)

      Theme.hook(
        'DrawCard',
        x - math.scale(3),
        cur_y,
        segment_w + math.scale(6),
        font_h,
        radius_small,
        emphasis_fill,
        false
      )
    end

    x = x + draw_text(segment.text, font, x, cur_y, is_emphasised and text_color or muted_color)
  end

  cur_y = cur_y + font_h + math.scale(4)

  for _, line_text in ipairs(info.lines) do
    local _, line_h = draw_text(line_text, small_font, padding, cur_y, text_color)

    cur_y = cur_y + line_h + math.scale(2)
  end

  if info.aliases then
    draw_text(info.aliases, small_font, padding, cur_y + math.scale(2), muted_color)
  end
end

--- Draws the suggestions above the text entry: the list of suggestions right above it, with
-- the selected one highlighted and scrolled into view, and a card about a command above the
-- list. The card is about the selected suggestion if that is a command or subcommand, else
-- about the command that has been typed, with the argument that is being typed emphasised
-- in its syntax. Shows that no commands were found if nothing fits.
-- @param width [Number width of the area to draw in]
-- @param bottom [Number bottom edge of the area to draw in; its top edge is 0]
function PANEL:draw_completion(width, bottom)
  local result = self.completion
  local candidates = result.candidates
  local count = #candidates
  local index = self.completion_index
  local selected = index and result.commands[index]
  local cmd = selected or result.command
  local padding, gap = math.scale(12), math.scale(6)
  local radius = get_option('corner_radius', math.scale(6))
  local background = ColorAlpha(get_color('surface'), 240)
  local font = get_font('text_normal')
  local font_h = draw.GetFontHeight(font)

  if !cmd and count == 0 then
    local card_h = font_h + padding * 2

    Theme.hook('DrawCard', 0, bottom - card_h, width, card_h, radius, background)
    draw_text(t'ui.chat.no_commands_found', font, padding, bottom - card_h + padding, get_color('accent_light'))

    return
  end

  local info = cmd and self:layout_command_info(cmd, !selected and result or nil, width - padding * 2)
  local info_h = info and info.height + padding * 2 or 0
  local list_y = bottom

  if count > 0 then
    local small_font = get_font('text_small')
    local more_h = draw.GetFontHeight(small_font)
    local row_h = font_h + math.scale(6)
    local room = bottom - (info and info_h + gap or 0) - padding * 2
    local rows = math.min(count, max_rows, math.floor(room / row_h))

    if rows < count then
      rows = math.min(rows, math.floor((room - more_h * 2) / row_h))
    end

    rows = math.max(rows, 1)

    local overflow = rows < count
    local list_h = rows * row_h + padding * 2 + (overflow and more_h * 2 or 0)
    local offset = scroll_offset(self.completion_offset, index, count, rows)
    local text_color, muted_color = get_color('text'), get_color('text_muted')
    local highlight = ColorAlpha(get_color('accent'), 200)
    local radius_small = get_option('corner_radius_small', math.scale(4))
    local prefix = result.token_index == 1 and self.completion_prefix or ''

    self.completion_offset = offset
    list_y = bottom - list_h

    Theme.hook('DrawCard', 0, list_y, width, list_h, radius, background)

    local y = list_y + padding

    if overflow then
      if offset > 0 then
        draw_text(t('ui.chat.more_above', { count = offset }), small_font, padding, y, muted_color)
      end

      y = y + more_h
    end

    for i = offset + 1, offset + rows do
      local is_selected = i == index
      local candidate_cmd = result.commands[i]

      if is_selected then
        Theme.hook('DrawCard', padding * 0.5, y, width - padding, row_h, radius_small, highlight, false)
      end

      local text_w = draw_text(prefix..candidates[i], font, padding, y + math.scale(3), text_color)

      if candidate_cmd then
        local syntax = t(candidate_cmd:get_syntax())

        if syntax != '[-]' then
          draw_text(syntax, font, padding + text_w + gap, y + math.scale(3), is_selected and text_color or muted_color)
        end
      end

      y = y + row_h
    end

    if overflow and offset + rows < count then
      draw_text(t('ui.chat.more_below', { count = count - offset - rows }), small_font, padding, y, muted_color)
    end
  end

  if info then
    self:draw_command_info(info, list_y - (count > 0 and gap or 0) - info_h, width, padding)
  end
end

--- Opens or closes the chatbox: toggles the focus and the text entry, and makes all
-- messages visible while the chatbox is open.
-- @param is_open [Boolean]
function PANEL:set_open(is_open)
  self.is_open = is_open

  if is_open then
    self:MakePopup()

    self.text_entry:SetVisible(true)
    self.text_entry:RequestFocus()
    self.text_entry.last_index = 0
    self.text_entry.history_value = nil
  else
    if self.text_entry:GetValue():is_command() then
      self.text_entry:SetText('')
    end

    self:reset_completion()
    self:KillFocus()

    self.text_entry:SetVisible(false)
  end

  for _, message in ipairs(self.history) do
    if IsValid(message) then
      message.force_show = is_open
    end
  end
end

--- Checks whether the text entry contains a command.
-- @return [Boolean whether a command is being typed; nil if the entry only contains
--   '/' or is not valid, Number length of the command prefix if a command is being typed]
function PANEL:typing_command()
  if IsValid(self.text_entry) then
    local cmd = self.text_entry:GetValue()

    if cmd != '/' then
      return cmd:is_command()
    end
  end
end

--- Compiles the message and creates a message panel for it,
-- without adding it to the chatbox.
-- @param message_data [Map message data received from the server]
-- @return [Panel the fl_chat_message panel, or nil if the message could not be compiled]
function PANEL:create_message(message_data)
  local parsed = Chatbox.compile(message_data)

  if !parsed then return end

  local panel = vgui.Create('fl_chat_message', self)
  local _half_padding = self.padding * 0.5

  panel:SetSize(self:GetWide() - self.padding * 2, self:GetWide() - self.padding * 2)
  panel:set_message(parsed)

  if self.is_open then
    panel.force_show = true
  end

  return panel
end

--- Creates a panel for the message and adds it to the chatbox, unless the
-- ChatboxShouldAddMessage hook returns false.
-- @param message_data [Map message data received from the server]
function PANEL:add_message(message_data)
  --- Decides whether a message received from the server is added to the chatbox. Called on the
  -- client before the message is compiled; gamemode hooks are not called.
  -- @param message_data [Map message data received from the server]
  -- @return [Boolean return false to drop the message]
  if message_data and Plugin.call('ChatboxShouldAddMessage', message_data) != false then
    local panel = self:create_message(message_data)

    if IsValid(panel) then
      self:add_panel(panel)

      timer.Simple(0.05, function()
        local scroll = self.scroll_panel
        local value = panel:GetTall() + self.padding

        if scroll:GetCanvas():GetTall() - scroll:GetTall() - scroll:GetVBar():GetScroll() <= value then
          self.scroll_panel:GetVBar():AddScroll(value)
        end
      end)
    end
  end
end

--- Drops removed panels from the message history, updates the indexes of the
-- remaining messages and rebuilds the layout.
function PANEL:rebuild_history_indexes()
  local new_history = {}

  for _, message in ipairs(self.history) do
    if IsValid(message) then
      local idx = table.insert(new_history, message)
      message.msg_index = idx
    end
  end

  self.history = new_history
  self:rebuild()
end

--- Appends a message panel to the history and to the scroll panel.
-- Ejects the oldest message first if the 'max_messages' limit has been reached.
-- @param panel [Panel a fl_chat_message panel]
function PANEL:add_panel(panel)
  if #self.history >= config_get('max_messages') then
    local last_history = self.history[1]

    if IsValid(last_history) then
      last_history:eject()
    else
      self:rebuild_history_indexes()
    end
  end

  local idx = table.insert(self.history, panel)

  panel:SetPos(self.padding, self.last_pos)
  panel.msg_index = idx

  self.scroll_panel:AddItem(panel)
  self.scroll_panel:GetVBar():AnimateTo(self.last_pos, 1, 0, -1)

  self.last_pos = self.last_pos + config_get('message_margin') + panel:GetTall()
end

--- Removes the message from the history and rebuilds the history indexes.
-- Does not remove the panel of the message.
-- @param idx [Number index of the message in the history]
function PANEL:remove_message(idx)
  table.remove(self.history, idx)
  self:rebuild_history_indexes()
end

--- Applies the size and position of the chatbox, lays out the text entry and the
-- scroll panel, and repositions all messages.
function PANEL:rebuild()
  self:SetSize(Chatbox.width, Chatbox.height)
  self:SetPos(Chatbox.x, Chatbox.y)

  local text_entry_height = get_option('chatbox_text_entry_height', 40)

  self.text_entry:SetSize(Chatbox.width, text_entry_height)
  self.text_entry:SetPos(0, Chatbox.height - text_entry_height)
  self.text_entry:SetFont(get_font('chatbox_text_entry'))
  self.text_entry:SetTextColor(get_color('text'))
  self.text_entry:RequestFocus()

  self.scroll_panel:SetSize(Chatbox.width, Chatbox.height - self.text_entry:GetTall() - 16)
  self.scroll_panel:PerformLayout()
  self.scroll_panel:GetVBar():SetScroll(self.scroll_panel:GetVBar().CanvasSize or 0)

  local padding = self.padding
  local message_margin = config_get('message_margin')
  local last_pos = 0

  for _, message in ipairs(self.history) do
    if IsValid(message) then
      message:SetPos(padding, last_pos)

      last_pos = last_pos + message_margin + message:GetTall()
    end
  end

  self.last_pos = last_pos
end

vgui.Register('fl_chat_panel', PANEL, 'fl_base_panel')
