local margin = math.scale(48)
local max_distance = 350 ^ 2
local fade_distance = 200 ^ 2
local color_white = Color(255, 255, 255)
local color_black = Color(0, 0, 0)

local function clamp_position_to_screen(x, y, text_w, text_h)
  return math.Clamp(x, margin + text_w * 0.5, ScrW() - text_w * 0.5 - margin),
         math.Clamp(y, margin, ScrH() - text_h * 0.5 - margin - text_h * 0.5)
end

function DisplayTyping:draw_player_typing_text(player, text, ply_pos, dist)
  local hide_text = Config.get('display_exact_message') == false
  local mult = hook.Run('DisplayTypingAdjustFadeoffMultiplier', player, text) or 1

  if hide_text then
    text = hook.Run('DisplayTypingTextType', player, text) or t'ui.hud.display_typing.typing'
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
    text = player:Name()..': '..text

    text_w, text_h = util.text_size(text, font)
    x, y = clamp_position_to_screen(screen_pos.x, screen_pos.y, text_w, text_h)
  end

  draw.SimpleTextOutlined(text, font, x, y, ColorAlpha(color_white, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, ColorAlpha(color_black, alpha))
end
