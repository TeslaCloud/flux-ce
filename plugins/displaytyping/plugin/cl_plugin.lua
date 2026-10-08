--- Client side of the Display Typing plugin: draws the text a player is typing above their
-- head.

local margin = math.scale(48)
local max_distance = 350 ^ 2
local fade_distance = 200 ^ 2
local color_white = Color(255, 255, 255)
local color_black = Color(0, 0, 0)

local function clamp_position_to_screen(x, y, text_w, text_h)
  return math.Clamp(x, margin + text_w * 0.5, ScrW() - text_w * 0.5 - margin),
         math.Clamp(y, margin, ScrH() - text_h * 0.5 - margin - text_h * 0.5)
end

--- Draws the text a player is typing above their head, fading it out with distance and
-- keeping it within screen bounds. Shows a generic 'typing' label instead of the text
-- when the 'display_exact_message' config is disabled. Nothing is drawn for a player who is
-- further away than 350 units, scaled by the DisplayTypingAdjustFadeoffMultiplier hook, or
-- who is within that distance but not in the local player's line of sight.
-- @param target [Player the player who is typing]
-- @param text [String the text being typed]
-- @param ply_pos [Vector eye position of the typing player]
-- @param dist [Number squared distance between the local player and the typing player]
function DisplayTyping:draw_player_typing_text(target, text, ply_pos, dist)
  local hide_text = Config.get('display_exact_message') == false
  --- Lets plugins scale the distance over which the typing text of a player fades out. Called
  -- on the client every frame for each player who is typing, however far away and whether
  -- or not they are in sight.
  -- @param target [Player the player who is typing]
  -- @param text [String the text being typed; long texts are cut to their last 45 characters]
  -- @return [Number multiplier of the squared distances at which the text starts to fade (200
  --   units) and has faded out (350 units), beyond which it is not drawn; 1 when nothing is
  --   returned]
  local mult = hook.Run('DisplayTypingAdjustFadeoffMultiplier', target, text) or 1

  if dist > max_distance * mult then return end
  if util.vector_obstructed(PLAYER:EyePos(), ply_pos, { PLAYER, target }) then return end

  if hide_text then
    --- Asks for the label to show in place of the text a player is typing. Called on the
    -- client, only while the 'display_exact_message' config is disabled.
    -- @param target [Player the player who is typing]
    -- @param text [String the text being typed; long texts are cut to their last 45
    --   characters]
    -- @return [String label to draw; the translated 'typing' label is used when nothing is
    --   returned]
    text = hook.Run('DisplayTypingTextType', target, text) or t'ui.hud.display_typing.typing'
  end

  local md, fd = max_distance * mult, fade_distance * mult
  local dist_diff = md - fd

  local pos = ply_pos + Vector(0, 0, 10 + math.sqrt(dist) * 0.09)
  local screen_pos = pos:ToScreen()

  local scrw, scrh = ScrW(), ScrH()
  local font = Theme.get_font('menu_large')
  local text_w, text_h = util.text_size(text, font)

  local x, y = clamp_position_to_screen(screen_pos.x, screen_pos.y, text_w, text_h)
  local alpha = 255

  if dist > fd then
    alpha = 255 - 255 * ((dist - fd) / dist_diff)
  end

  if screen_pos.x != x or screen_pos.y != y then
    text = target:Name()..': '..text

    text_w, text_h = util.text_size(text, font)
    x, y = clamp_position_to_screen(screen_pos.x, screen_pos.y, text_w, text_h)
  end

  draw.SimpleTextOutlined(
    text,
    font,
    x,
    y,
    ColorAlpha(color_white, alpha),
    TEXT_ALIGN_CENTER,
    TEXT_ALIGN_CENTER,
    1,
    ColorAlpha(color_black, alpha)
  )
end
