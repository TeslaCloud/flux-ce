--- Client-side hooks of the RolePlay Commands plugin: they draw the static texts, hide what
-- players say through the engine instead of the chatbox, and tell the Display Typing plugin
-- what kind of speech a player is typing (talking, whispering, yelling or performing, see
-- `RPCommands:get_typing_kind`), so that the typing bubble is labeled, colored like the chat
-- line the text will become, and seen as far as that line will be heard.

local IsValid = IsValid
local isfunction = isfunction
local text_size = util.text_size
const draw_text_outlined = draw.SimpleTextOutlined
const wrap_text = util.wrap_text

const text_color = Color(255, 255, 255)
const text_outline_color = Color(0, 0, 0)

--- Checks whether a text is out of character chat behind a prefix that starts like a command,
-- such as `//`, `/ooc` and `/looc`.
-- @param text [String the text being typed, or its outline]
-- @return [Boolean]
local function is_command_like_ooc(text)
  local prefix_id, prefix = Chatbox.find_prefix(text)

  if prefix_id != 'ooc' and prefix_id != 'looc' then return false end

  local command_prefixes = Config.get('flow_command_prefixes') or {}

  for i = 1, #command_prefixes do
    if prefix:start_with(command_prefixes[i]) then
      return true
    end
  end

  return false
end

--- Returns the lines a static text is drawn in and the height of its text, wrapped again only
-- when the font or the screen width differ from the ones it was last wrapped for.
-- @param text_data [Map the static text]
-- @param font [String font the text is drawn with]
-- @param scrw [Number screen width]
-- @param cx [Number horizontal center of the screen]
-- @return [List<String> lines, Number height of the text]
local function get_wrapped_lines(text_data, font, scrw, cx)
  if text_data.wrapped_font != font or text_data.wrapped_scrw != scrw then
    local full_w, full_h = text_size(text_data.text, font)

    text_data.wrapped_lines = wrap_text(text_data.text, font, scrw * 0.25, cx - full_w * 0.5)
    text_data.wrapped_height = full_h
    text_data.wrapped_font = font
    text_data.wrapped_scrw = scrw
  end

  return text_data.wrapped_lines, text_data.wrapped_height
end

--- Draws one line of a static text centered on a point.
-- @param line [String]
-- @param font [String]
-- @param x [Number horizontal center of the line]
-- @param y [Number top of the line]
-- @param offset [Number space below the line]
-- @return [Number top of the next line]
local function draw_line(line, font, x, y, offset)
  local w, h = text_size(line, font)

  draw_text_outlined(line, font, x - w * 0.5, y, text_color, nil, nil, 1, text_outline_color)

  return y + h + offset
end

--- Draws nearby visible static texts, fading with distance and screen position. Staff holding Alt also see
-- who placed each text and when.
function RPCommands:HUDPaint()
  local client = PLAYER
  local texts = RPCommands.texts

  if !IsValid(client) or !next(texts) then return end

  local client_pos = EyePos()
  local scrw = ScrW()
  local cx, cy = ScrC()
  local font = Theme.get_font('menu_small')
  local show_author = input.IsKeyDown(KEY_LALT) and client:is_assistant()
  local offset = 4

  for _, text_data in pairs(texts) do
    local text_pos = text_data.pos

    if client_pos:DistToSqr(text_pos) <= 90_000 and !util.vector_obstructed(client_pos, text_pos, client) then
      local pos = text_pos:ToScreen()
      local x = pos.x
      local cam_mult = (1 - math.Distance(cx, cy, x, pos.y) / scrw * 1.5)
      local distance_mult = (1 - client_pos:Distance(text_pos) / 300)
      local alpha = 255 * cam_mult * distance_mult
      local lines, full_h = get_wrapped_lines(text_data, font, scrw, cx)
      local line_count = show_author ? #lines + 2 : #lines
      local cur_y = pos.y - ((full_h + offset) * line_count) * 0.5

      text_color.a = alpha
      text_outline_color.a = alpha

      for i = 1, #lines do
        cur_y = draw_line(lines[i], font, x, cur_y, offset)
      end

      if show_author then
        text_data.author_line = text_data.author_line or text_data.name..' ('..text_data.steamid..')'

        cur_y = draw_line(text_data.author_line, font, x, cur_y, offset)
        draw_line(text_data.time, font, x, cur_y, offset)
      end
    end
  end
end

--- Keeps what players say through the engine out of the chat. What is typed into the chatbox
-- reaches the server through the chatbox itself and comes back as a line of roleplay chat.
-- Plain text sent with the `say` console command does not: the base gamemode would show it
-- to every player on the server under the real name of the speaker, past the talk radius,
-- recognition and the speaking rules. Chat prefixes and commands in such a text are handled
-- by the server before it gets here, and the lines of the server console are added by the
-- Chatbox plugin.
-- @param speaker [Player the speaker, an invalid entity for the server console]
-- @param _text [String the message]
-- @param _team_chat [Boolean whether the message was sent to the team chat]
-- @param _is_dead [Boolean whether the speaker is dead]
-- @return [Boolean true to hide what a player has said, nil for the server console]
function RPCommands:OnPlayerChat(speaker, _text, _team_chat, _is_dead)
  if IsValid(speaker) then
    return true
  end
end

--- Keeps the colors of the registered kinds of speech in step with the chat colors, which
-- arrive from the server after the kinds have been registered.
-- @param key [String config key]
-- @param _old_value [Any value the client had before]
-- @param _new_value [Any value that has been received]
function RPCommands:ConfigReceived(key, _old_value, _new_value)
  if !DisplayTyping or !isfunction(DisplayTyping.find_kind) then return end

  for id, data in pairs(self.typing_kinds) do
    local kind = data.color == key and DisplayTyping:find_kind(id)

    if kind then
      kind.color = util.to_color(Config.get(key))
    end
  end
end

--- Gives the typing bubble of a player the kind of speech they are typing: talking,
-- whispering, yelling or performing (see `RPCommands:get_typing_kind`), each registered with
-- its label, its color and the range of its default volume. A knocked out player gets no
-- bubble for in character speech, which they cannot say. Out of character chat typed behind
-- a prefix that starts like a command (`//`, `/ooc`, `/looc`) gets the plain typing bubble;
-- `.//`, `[[` and the other chat prefixes are left to the other plugins.
-- @param target [Player player that is typing]
-- @param text [String text being typed, or its outline]
-- @return [String/Boolean ID of the kind of speech, false to show no bubble, nil for
--   anything else that is not in character speech]
function RPCommands:GetTypingKind(target, text)
  local id = self:get_typing_kind(text)

  if !id then
    return is_command_like_ooc(text) ? 'typing' : nil
  end

  if IsValid(target) and isfunction(target.is_knocked_out) and target:is_knocked_out() then
    return false
  end

  return id
end

--- Fits the typing bubble of in character speech to the phrase being typed: the color of
-- the chat line it will become and the range that line will be heard from, which follows
-- the volume of the phrase, so that `((` shrinks the bubble of a whisper and `!!!` widens
-- the one of a yell. Out of character chat behind a prefix that starts like a command shows
-- no text, as commands do.
-- @param _target [Player player that is typing]
-- @param text [String text being typed, or its outline]
-- @param display [Map what the bubble shows, changed in place]
function RPCommands:AdjustTypingDisplay(_target, text, display)
  local id, volume = self:get_typing_kind(text)

  if id and display.id == id then
    display.color = util.to_color(Config.get(self.typing_kinds[id].color))
    display.range = self:get_volume_range(volume)
  elseif !id and display.id == 'typing' and is_command_like_ooc(text) then
    display.live = false
  end
end
