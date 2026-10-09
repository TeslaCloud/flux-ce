--- The typing bubbles of the Display Typing plugin: one for every player nearby whom the
-- server has reported as typing.
-- A bubble shows three animated dots, the name of the player as the viewer knows it, the
-- kind of speech and, if the text may be shown, the last lines of the text. While the head
-- of the player is on screen the bubble sits above it; otherwise it is held at the edge of
-- the screen in the direction of the player, with a pointer that way, and a player who is
-- behind the viewer ends up at the bottom. Bubbles fade in and out, ease towards their place
-- and size, and are moved apart when several of them would overlap. A bubble is hidden
-- when the player is dead, not drawn or out of range, and when a wall is in the way unless
-- the 'display_typing_through_walls' config is enabled.
--
-- Themes restyle the bubbles with the 'typing_bubble_name', 'typing_bubble_kind' and
-- 'typing_bubble_text' fonts, the 'typing_bubble_background', 'typing_bubble_text' and
-- 'typing_bubble_accent' colors, the 'typing_bubble_width' (of the live text),
-- 'typing_bubble_lines', 'typing_bubble_padding', 'typing_bubble_rounding',
-- 'typing_bubble_margin' (to the edges of the screen), 'typing_bubble_pointer',
-- 'typing_bubble_spacing', 'typing_bubble_gap' (between bubbles) and 'typing_bubble_dot'
-- options, or draw them entirely on their own from the `PaintTypingBubble` theme hook.

local bubbles = DisplayTyping.bubbles or {}
DisplayTyping.bubbles = bubbles

DisplayTyping.fade_start = 0.6
DisplayTyping.sight_grace = 0.6
DisplayTyping.sight_interval = 0.15
DisplayTyping.behind_bias = 0.5
DisplayTyping.tail_length = 200

local bubble_count = 0
local metrics = {}
local view = {}
local listed = {}
local triangle = { { x = 0, y = 0 }, { x = 0, y = 0 }, { x = 0, y = 0 } }
local ignored_first, ignored_second
local trace_result = {}
local metrics_dirty = true
local lifted_position = Vector()
local view_offset = Vector()
local accent_color = Color(255, 255, 255)
local text_color = Color(255, 255, 255)
local background_color = Color(0, 0, 0)
local dot_color = Color(255, 255, 255)
local caret_color = Color(255, 255, 255)

--- Decides whether an entity blocks the line of sight to a typing player. Players, NPCs,
-- ragdolls, weapons and the vehicles the two players sit in do not.
-- @param entity [Entity entity the trace has run into]
-- @return [Boolean true if the entity is in the way]
local function blocks_sight(entity)
  if entity == ignored_first or entity == ignored_second then
    return false
  end

  return !(entity:IsPlayer() or entity:IsNPC() or entity:IsRagdoll() or entity:IsWeapon())
end

local trace_data = {
  mask = MASK_VISIBLE,
  filter = blocks_sight,
  output = trace_result
}

--- Copies a color into one of the colors that are kept for drawing, at an opacity, so that
-- drawing a bubble does not create colors every frame.
-- @param target [Color color to write to]
-- @param source [Color color to copy]
-- @param alpha [Number opacity from 0 to 255]
-- @return [Color the target]
local function tint(target, source, alpha)
  target.r, target.g, target.b, target.a = source.r, source.g, source.b, alpha

  return target
end

--- Moves a value towards its goal by a share of the remaining difference that does not
-- depend on the frame rate.
-- @param value [Number current value]
-- @param goal [Number value to move towards]
-- @param delta [Number seconds since the last frame]
-- @param speed [Number how fast to move; about that many times per second the remaining
--   difference shrinks to a third]
-- @return [Number]
local function approach(value, goal, delta, speed)
  return value + (goal - value) * (1 - math.exp(-delta * speed))
end

--- Orders bubbles by age, so that the ones that have been around longer keep their place
-- when bubbles are moved apart.
-- @param a [Map bubble]
-- @param b [Map bubble]
-- @return [Boolean true if a was created before b]
local function by_order(a, b)
  return a.order < b.order
end

--- Draws a filled triangle.
-- @param x1 [Number x of the first corner]
-- @param y1 [Number y of the first corner]
-- @param x2 [Number x of the second corner, clockwise from the first]
-- @param y2 [Number y of the second corner]
-- @param x3 [Number x of the third corner]
-- @param y3 [Number y of the third corner]
-- @param color [Color]
local function draw_triangle(x1, y1, x2, y2, x3, y3, color)
  triangle[1].x, triangle[1].y = x1, y1
  triangle[2].x, triangle[2].y = x2, y2
  triangle[3].x, triangle[3].y = x3, y3

  surface.SetDrawColor(color.r, color.g, color.b, color.a)
  draw.NoTexture()
  surface.DrawPoly(triangle)
end

--- Wraps the end of a text into lines that fit a width, keeping only the last lines. The
-- sizes are measured directly rather than through `util.text_size`, which would remember
-- every state of a text that changes with each key press.
-- @param text [String text to wrap]
-- @param font [String font name]
-- @param width [Number maximum width of a line in pixels]
-- @param max_lines [Number how many lines to keep, counted from the end]
-- @return [List<Map> lines as { text, w } tables, or nil if there is nothing to show,
--   Number width of the widest line, Number height of a line]
local function wrap_tail(text, font, width, max_lines)
  local length = utf8.len(text)

  if !length or max_lines < 1 or width <= 0 then return end

  local cut = false
  local limit = DisplayTyping.tail_length

  if length > limit then
    text = text:utf8sub(length - limit + 1, length)
    cut = true
  end

  surface.SetFont(font)

  local pieces = {}
  local current = ''

  for word in text:gmatch('%S+') do
    local candidate = current == '' and word or current..' '..word

    if surface.GetTextSize(candidate) <= width then
      current = candidate
    else
      if current != '' then
        table.insert(pieces, current)
      end

      current = word

      local current_width = surface.GetTextSize(current)

      while current_width > width do
        local keep = math.max(math.floor(utf8.len(current) * width / current_width), 1)
        local part = current:utf8sub(1, keep)

        while keep > 1 and surface.GetTextSize(part) > width do
          keep = keep - 1
          part = current:utf8sub(1, keep)
        end

        table.insert(pieces, part)

        current = current:utf8sub(keep + 1)
        current_width = surface.GetTextSize(current)
      end
    end
  end

  if current != '' then
    table.insert(pieces, current)
  end

  if #pieces == 0 then return end

  local first = math.max(#pieces - max_lines + 1, 1)

  if first > 1 or cut then
    pieces[first] = DisplayTyping.placeholder..pieces[first]
  end

  local lines = {}
  local widest, line_height = 0, 0

  for i = first, #pieces do
    local w, h = surface.GetTextSize(pieces[i])

    table.insert(lines, { text = pieces[i], w = w })

    widest = math.max(widest, w)
    line_height = math.max(line_height, h)
  end

  return lines, widest, line_height
end

--- Creates or updates the typing bubble of a player with what the server has sent about
-- them. A bubble that was fading out comes back.
-- @param index [Number entity index of the typing player]
-- @param text [String the text being typed, or its outline]
-- @param exact [Boolean true if the text is what the player is typing rather than its
--   outline]
function DisplayTyping:update_bubble(index, text, exact)
  if !isnumber(index) or !isstring(text) then return end

  local bubble = bubbles[index]

  if !bubble then
    bubble_count = bubble_count + 1

    bubble = {
      index = index,
      order = bubble_count,
      alpha = 0,
      phase = math.Rand(0, 1)
    }

    bubbles[index] = bubble
  end

  bubble.text = text
  bubble.exact = exact == true
  bubble.typing = true
  bubble.stale = true
end

--- Marks the typing bubble of a player as finished, which makes it fade out and go away.
-- @param index [Number entity index of the player]
function DisplayTyping:stop_bubble(index)
  local bubble = bubbles[index]

  if bubble then
    bubble.typing = false
  end
end

--- Checks whether the local player has a clear line of sight to a typing player. The trace
-- is repeated every `sight_interval` seconds for each bubble, and a line of sight that has
-- been lost still counts for `sight_grace` seconds, so that bubbles do not flicker when
-- something passes in between. Always true if the 'display_typing_through_walls' config is
-- enabled.
-- @param bubble [Map the bubble of the typing player]
-- @param target [Player the typing player]
-- @param position [Vector position of the head of the typing player]
-- @param now [Number RealTime() of the frame]
-- @return [Boolean]
function DisplayTyping:has_sight(bubble, target, position, now)
  if Config.get('display_typing_through_walls') then
    return true
  end

  if now >= (bubble.next_trace or 0) then
    bubble.next_trace = now + self.sight_interval

    ignored_first = PLAYER:InVehicle() and PLAYER:GetVehicle() or nil
    ignored_second = target:InVehicle() and target:GetVehicle() or nil

    trace_data.start = view.eyes
    trace_data.endpos = position

    util.TraceLine(trace_data)

    if !trace_result.Hit then
      bubble.seen_at = now
    end
  end

  return bubble.seen_at != nil and now - bubble.seen_at <= self.sight_grace
end

--- Brings a bubble up to date with its player for the frame: finds the player, works out
-- the kind of speech again if the text has changed, refreshes the name and the position
-- of the head, and decides how visible the bubble should be.
-- @param bubble [Map]
-- @param now [Number RealTime() of the frame]
-- @return [Number opacity the bubble should have, from 0 (hidden) to 1; it falls off over
--   the last part of the range]
function DisplayTyping:watch_bubble(bubble, now)
  bubble.fresh = false

  local target = bubble.target

  if !IsValid(target) then
    target = Entity(bubble.index)

    if !IsValid(target) or !target:IsPlayer() then
      bubble.target = nil

      return 0
    end

    bubble.target = target
  end

  if bubble.stale then
    bubble.stale = false
    bubble.kind = self:get_kind(target, bubble.text)
    bubble.dirty = true
  end

  if now >= (bubble.next_name or 0) then
    bubble.next_name = now + 0.5

    bubble.name = tostring(target:name())
  end

  if !target:Alive() or target:IsDormant() then
    return 0
  end

  local ragdoll = self:get_ragdoll(target)

  if !ragdoll and target:GetNoDraw() then
    return 0
  end

  local head = ragdoll and ragdoll:WorldSpaceCenter() or target:EyePos()
  local distance = view.eyes:Distance(head)

  bubble.fresh = true
  bubble.head = head
  bubble.distance = distance
  bubble.lift = ragdoll and 16 or 10 + distance * 0.02

  local kind = bubble.kind

  if !bubble.typing or !kind then
    return 0
  end

  local range = self:get_range() * kind.range

  if distance >= range or !self:has_sight(bubble, target, head, now) then
    return 0
  end

  local fade_from = range * self.fade_start

  if distance <= fade_from then
    return 1
  end

  return 1 - (distance - fade_from) / (range - fade_from)
end

--- Has the fonts, colors and sizes of the bubbles read from the theme again before the next
-- frame. The plugin does so when a theme has been loaded, the screen size has changed and
-- the live text setting or config has been switched.
function DisplayTyping:invalidate_metrics()
  metrics_dirty = true
end

--- Reads the fonts, colors and sizes of the bubbles from the active theme, falling back to
-- the general fonts and colors of the theme, and whether live text is shown. Done before the
-- first frame and again after `DisplayTyping:invalidate_metrics`, not every frame.
function DisplayTyping:update_metrics()
  metrics.name_font = Theme.get_font('typing_bubble_name', Theme.get_font('text_bar', 'flRoboto'))
  metrics.kind_font = Theme.get_font('typing_bubble_kind', Theme.get_font('text_smallest', 'flRoboto'))
  metrics.text_font = Theme.get_font('typing_bubble_text', Theme.get_font('text_small', 'flRoboto'))
  metrics.background = Theme.get_color('typing_bubble_background', ColorAlpha(Theme.get_color('background'), 230))
  metrics.text = Theme.get_color('typing_bubble_text', Theme.get_color('text'))
  metrics.accent = Theme.get_color('typing_bubble_accent', Theme.get_color('accent_light'))
  metrics.width = Theme.get_option('typing_bubble_width', math.scale(340))
  metrics.lines = Theme.get_option('typing_bubble_lines', 3)
  metrics.padding = Theme.get_option('typing_bubble_padding', math.scale(10))
  metrics.rounding = Theme.get_option('typing_bubble_rounding', math.scale(8))
  metrics.margin = Theme.get_option('typing_bubble_margin', math.scale(24))
  metrics.pointer = Theme.get_option('typing_bubble_pointer', math.scale(8))
  metrics.spacing = Theme.get_option('typing_bubble_spacing', math.scale(8))
  metrics.gap = Theme.get_option('typing_bubble_gap', math.scale(6))
  metrics.dot = Theme.get_option('typing_bubble_dot', math.scale(6))
  metrics.dot_gap = math.max(math.floor(metrics.dot * 0.5), 1)
  metrics.dots_width = metrics.dot * 3 + metrics.dot_gap * 2
  metrics.caret = math.max(math.scale(2), 1)
  metrics.live = self:live_text_allowed() and self:get_preference('display_typing_live_text')
end

--- Works out what a bubble shows and how large it has to be: the label and the color of the
-- kind of speech, the wrapped lines of the live text if it is shown, and the size the bubble
-- eases towards. The lines are only wrapped again when the text or the look has changed, and
-- the name and the label are only measured again when they or their fonts have changed.
-- @param bubble [Map]
function DisplayTyping:layout_bubble(bubble)
  local kind = bubble.kind

  if kind then
    bubble.label = kind.label
    bubble.color = kind.color
  end

  local live = kind != nil and kind.live and bubble.exact and metrics.live

  if live != bubble.live or bubble.wrap_font != metrics.text_font or bubble.wrap_width != metrics.width
  or bubble.wrap_lines != metrics.lines then
    bubble.dirty = true
  end

  if bubble.dirty then
    bubble.dirty = false
    bubble.live = live
    bubble.wrap_font = metrics.text_font
    bubble.wrap_width = metrics.width
    bubble.wrap_lines = metrics.lines
    bubble.lines, bubble.lines_width, bubble.line_height = nil, nil, nil

    if live then
      bubble.lines, bubble.lines_width, bubble.line_height =
        wrap_tail(bubble.text, metrics.text_font, metrics.width, metrics.lines)
    end
  end

  if bubble.measured_name != bubble.name or bubble.measured_name_font != metrics.name_font then
    bubble.measured_name = bubble.name
    bubble.measured_name_font = metrics.name_font
    bubble.name_width, bubble.name_height = util.text_size(bubble.name or '', metrics.name_font)
  end

  local label = bubble.label or ''

  if bubble.measured_label != label or bubble.measured_label_font != metrics.kind_font then
    bubble.measured_label = label
    bubble.measured_label_font = metrics.kind_font
    bubble.label_width, bubble.label_height = 0, 0

    if label != '' then
      bubble.label_width, bubble.label_height = util.text_size(label, metrics.kind_font)
    end
  end

  local name_width, name_height = bubble.name_width, bubble.name_height
  local label_width, label_height = bubble.label_width, bubble.label_height
  local width = metrics.dots_width + metrics.spacing + name_width
  local height = math.max(name_height, label_height, metrics.dot)

  if label_width > 0 then
    width = width + metrics.spacing + label_width
  end

  bubble.header_height = height

  if bubble.lines then
    width = math.max(width, bubble.lines_width + metrics.caret * 3)
    height = height + metrics.spacing * 0.5 + #bubble.lines * bubble.line_height
  end

  bubble.goal_w = width + metrics.padding * 2
  bubble.goal_h = height + metrics.padding * 2
end

--- Works out where a bubble wants to be on the screen. If the head of the player is on
-- screen the bubble goes above it, kept within the margins. Otherwise it goes to the edge of
-- the screen in the direction of the player as seen from the middle of the screen; a player
-- behind the viewer is pulled towards the bottom edge the further behind they are. A bubble
-- that is not tracking its player this frame keeps the place it had.
-- @param bubble [Map]
function DisplayTyping:aim_bubble(bubble)
  if !bubble.fresh then return end

  lifted_position:Set(bubble.head)
  lifted_position.z = lifted_position.z + bubble.lift
  view_offset:Set(lifted_position)
  view_offset:Sub(view.origin)

  local depth, side, rise = view_offset:Dot(view.forward), view_offset:Dot(view.right), view_offset:Dot(view.up)
  local w, h = bubble.goal_w, bubble.goal_h
  local margin = metrics.margin
  local inside = false
  local screen_x, screen_y

  if depth > 8 then
    local screen = lifted_position:ToScreen()
    local inset = margin + (bubble.edge and margin or 0)

    screen_x, screen_y = screen.x, screen.y
    inside = screen_x >= inset and screen_x <= view.w - inset and screen_y >= inset and screen_y <= view.h - inset
  end

  if inside then
    bubble.edge = false
    bubble.anchor_x, bubble.anchor_y = screen_x, screen_y
    bubble.direction_x, bubble.direction_y = 0, 1
    bubble.goal_x = math.Clamp(screen_x, margin + w * 0.5, view.w - margin - w * 0.5)
    bubble.goal_y = math.Clamp(screen_y - metrics.pointer - h * 0.5, margin + h * 0.5, view.h - margin - h * 0.5)

    return
  end

  local direction_x, direction_y = side, -rise

  if depth < 0 then
    direction_y = direction_y - depth * self.behind_bias
  end

  local length = math.sqrt(direction_x * direction_x + direction_y * direction_y)

  if length < 0.001 then
    direction_x, direction_y, length = 0, 1, 1
  end

  direction_x, direction_y = direction_x / length, direction_y / length

  local reach_x = (view.w * 0.5 - margin - metrics.pointer - w * 0.5) / math.max(math.abs(direction_x), 0.0001)
  local reach_y = (view.h * 0.5 - margin - metrics.pointer - h * 0.5) / math.max(math.abs(direction_y), 0.0001)
  local reach = math.min(reach_x, reach_y)

  bubble.edge = true
  bubble.anchor_x, bubble.anchor_y = nil, nil
  bubble.direction_x, bubble.direction_y = direction_x, direction_y
  bubble.goal_x = view.w * 0.5 + direction_x * reach
  bubble.goal_y = view.h * 0.5 + direction_y * reach
end

--- Moves bubbles apart so that they do not cover each other. Older bubbles keep the place
-- they want; a newer one that would overlap is moved up or down until it is clear of the
-- ones before it. A bubble above a head moves up, away from the player, unless it is close
-- to the top of the screen; one at the edge moves towards the middle of the screen.
-- @param count [Number how many bubbles are listed for drawing this frame]
function DisplayTyping:arrange_bubbles(count)
  local gap = metrics.gap

  for i = 1, count do
    local bubble = listed[i]
    local x, y = bubble.goal_x, bubble.goal_y
    local w, h = bubble.goal_w, bubble.goal_h

    bubble.push = bubble.push or (y < view.h * (bubble.edge and 0.5 or 0.25) and 1 or -1)

    for pass = 1, i do
      local moved = false

      for j = 1, i - 1 do
        local other = listed[j]
        local clear_x = (w + other.goal_w) * 0.5 + gap
        local clear_y = (h + other.goal_h) * 0.5 + gap

        if math.abs(x - other.place_x) < clear_x and math.abs(y - other.place_y) < clear_y then
          y = other.place_y + bubble.push * clear_y
          moved = true
        end
      end

      if !moved then break end
    end

    if y == bubble.goal_y then
      bubble.push = nil
    end

    bubble.place_x = x
    bubble.place_y = math.Clamp(y, metrics.margin + h * 0.5, view.h - metrics.margin - h * 0.5)
  end
end

--- Eases a bubble towards its place and size. A bubble that has just appeared starts there.
-- A bubble above a head follows quickly, one at the edge of the screen glides.
-- @param bubble [Map]
-- @param delta [Number seconds since the last frame]
function DisplayTyping:move_bubble(bubble, delta)
  if !bubble.placed then
    bubble.placed = true
    bubble.x, bubble.y = bubble.place_x, bubble.place_y
    bubble.w, bubble.h = bubble.goal_w, bubble.goal_h

    return
  end

  local speed = bubble.edge and 12 or 36

  bubble.x = approach(bubble.x, bubble.place_x, delta, speed)
  bubble.y = approach(bubble.y, bubble.place_y, delta, speed)
  bubble.w = approach(bubble.w, bubble.goal_w, delta, 20)
  bubble.h = approach(bubble.h, bubble.goal_h, delta, 20)
end

--- Draws a bubble: the box with its pointer, the animated dots, the name, the label of the
-- kind of speech and the live text with a blinking caret. The PaintTypingBubble theme hook
-- can take the drawing over.
-- @param bubble [Map]
-- @param now [Number RealTime() of the frame]
function DisplayTyping:draw_bubble(bubble, now)
  local fraction = bubble.alpha
  local alpha = fraction * 255
  local w, h = math.Round(bubble.w), math.Round(bubble.h)
  local x = math.Round(bubble.x - w * 0.5)
  local y = math.Round(bubble.y - h * 0.5 + (1 - fraction) * metrics.padding)

  --- Lets the active theme draw a typing bubble in place of the default drawing. Called on
  -- the client every frame for every visible bubble, from the HUDPaint hook.
  -- @param bubble [Map the bubble: target (Player), name (String name of the player as the
  --   viewer knows it), label (String label of the kind of speech), color (Color of the kind,
  --   or nil), kind (Map as returned by `DisplayTyping:get_kind`, or nil), lines (List of
  --   { text, w } lines of live text, or nil), line_height (Number), edge (Boolean true if
  --   the player is off screen), direction_x and direction_y (Numbers, unit vector on the
  --   screen pointing from the bubble towards the player), anchor_x and anchor_y (Numbers,
  --   screen position right above the head, nil at the edge), phase (Number 0 to 1, offset
  --   for animations)]
  -- @param x [Number left of the bubble]
  -- @param y [Number top of the bubble]
  -- @param w [Number width of the bubble]
  -- @param h [Number height of the bubble]
  -- @param alpha [Number opacity of the bubble from 0 to 255]
  -- @return [Any return anything but nil to skip the default drawing]
  if Theme.hook('PaintTypingBubble', bubble, x, y, w, h, alpha) != nil then return end

  local accent = bubble.color or metrics.accent
  local pointer = metrics.pointer

  tint(accent_color, accent, alpha)
  tint(text_color, metrics.text, alpha)
  tint(background_color, metrics.background, metrics.background.a * fraction)

  draw.RoundedBox(metrics.rounding, x, y, w, h, background_color)

  if bubble.edge then
    local direction_x, direction_y = bubble.direction_x, bubble.direction_y
    local reach = math.min(
      w * 0.5 / math.max(math.abs(direction_x), 0.0001),
      h * 0.5 / math.max(math.abs(direction_y), 0.0001)
    )
    local base_x = x + w * 0.5 + direction_x * reach
    local base_y = y + h * 0.5 + direction_y * reach
    local half = pointer * 0.7

    draw_triangle(
      base_x + direction_x * pointer, base_y + direction_y * pointer,
      base_x - direction_y * half, base_y + direction_x * half,
      base_x + direction_y * half, base_y - direction_x * half,
      accent_color
    )
  elseif bubble.anchor_y and bubble.anchor_y >= y + h and w > (metrics.rounding + pointer) * 2 then
    local tip_x = math.Clamp(bubble.anchor_x, x + metrics.rounding + pointer, x + w - metrics.rounding - pointer)

    draw_triangle(tip_x - pointer, y + h, tip_x + pointer, y + h, tip_x, y + h + pointer, background_color)
  end

  local dot = metrics.dot
  local left = x + metrics.padding
  local middle = y + metrics.padding + bubble.header_height * 0.5

  render.SetScissorRect(x, y, x + w, y + h, true)
    for i = 0, 2 do
      local cycle = (now * 1.3 + bubble.phase - i * 0.16) % 1
      local hop = cycle < 0.45 and math.sin(cycle / 0.45 * math.pi) or 0

      draw.RoundedBox(
        dot * 0.5,
        left + i * (dot + metrics.dot_gap),
        middle - dot * 0.5 - hop * dot * 0.6,
        dot,
        dot,
        tint(dot_color, accent, alpha * (0.45 + 0.55 * hop))
      )
    end

    local name_x = left + metrics.dots_width + metrics.spacing

    draw.SimpleText(
      bubble.name or '', metrics.name_font, name_x, middle, text_color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
    )

    if bubble.label and bubble.label != '' then
      draw.SimpleText(
        bubble.label,
        metrics.kind_font,
        name_x + bubble.name_width + metrics.spacing,
        middle,
        accent_color,
        TEXT_ALIGN_LEFT,
        TEXT_ALIGN_CENTER
      )
    end

    local lines = bubble.lines

    if lines then
      local line_height = bubble.line_height
      local line_y = y + metrics.padding + bubble.header_height + metrics.spacing * 0.5

      for i, line in ipairs(lines) do
        draw.SimpleText(line.text, metrics.text_font, left, line_y + (i - 1) * line_height, text_color)
      end

      draw.box(
        left + lines[#lines].w + metrics.caret,
        line_y + (#lines - 1) * line_height + line_height * 0.15,
        metrics.caret,
        line_height * 0.7,
        tint(caret_color, accent, alpha * (0.5 + 0.5 * math.sin(now * 6 + bubble.phase)))
      )
    end
  render.SetScissorRect(0, 0, 0, 0, false)
end

--- Updates and draws all typing bubbles for the frame: fades each one towards the opacity
-- it should have, forgets the ones that have finished and faded out, then lays out, places,
-- moves and draws the rest. Nothing is shown while the player has typing bubbles turned off
-- in the client settings. If the bubbles have not been drawn for half a second, because
-- the HUD was hidden, they start over from invisible rather than from where they were left.
function DisplayTyping:draw_bubbles()
  if next(bubbles) == nil then return end

  local now = RealTime()
  local delta = math.min(RealFrameTime(), 0.1)
  local enabled = self:get_preference('display_typing_bubbles')
  local angles = EyeAngles()

  if now - (self.drawn_at or 0) > 0.5 then
    for index, bubble in pairs(bubbles) do
      bubble.alpha = 0
      bubble.placed = false
    end
  end

  self.drawn_at = now

  view.w, view.h = ScrW(), ScrH()
  view.origin = EyePos()
  view.forward, view.right, view.up = angles:Forward(), angles:Right(), angles:Up()
  view.eyes = PLAYER:EyePos()

  if metrics_dirty then
    metrics_dirty = false

    self:update_metrics()
  end

  local count = 0

  for index, bubble in pairs(bubbles) do
    local goal = 0

    if enabled then
      goal = self:watch_bubble(bubble, now)
    else
      bubble.fresh = false
    end

    bubble.alpha = approach(bubble.alpha, goal, delta, 10)

    if goal == 0 and bubble.alpha < 0.01 then
      bubble.alpha = 0
      bubble.placed = false

      if !bubble.typing then
        bubbles[index] = nil
      end
    elseif bubble.goal_x or bubble.fresh then
      count = count + 1
      listed[count] = bubble
    end
  end

  for i = #listed, count + 1, -1 do
    listed[i] = nil
  end

  if count == 0 then return end

  table.sort(listed, by_order)

  for i = 1, count do
    self:layout_bubble(listed[i])
    self:aim_bubble(listed[i])
  end

  self:arrange_bubbles(count)

  for i = 1, count do
    self:move_bubble(listed[i], delta)
    self:draw_bubble(listed[i], now)
  end
end
