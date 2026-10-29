--- The admin ESP of the Observer plugin: for every other player it draws their name and
-- Steam name, an outline box and health and armor bars, visible through walls. Observer's
-- HUDPaint handler draws it for a noclipping player with the 'admin_esp' permission. Its
-- colors are the `esp_red`, `esp_blue` and `esp_grey` colors of the theme.

if !Observer then
  PLUGIN:set_global('Observer')
end

local draw_simple_text = draw.SimpleText
local draw_rounded_box = draw.RoundedBox
local set_draw_color = surface.SetDrawColor
local draw_outlined_rect = surface.DrawOutlinedRect
local player_iterator = player.Iterator
local get_all_teams = team.GetAllTeams
local get_font = Theme.get_font
local text_size = util.text_size
local clamp = math.Clamp
local max = math.max

local color_lightred = Color(255, 100, 100)
local color_lightblue = Color(200, 200, 255)
local color_grey = Color(100, 100, 100)
local color_red = Color(255, 0, 0)
local color_blue = Color(0, 0, 255)
const color_fallback = Color(255, 255, 255)
const offset_pos = Vector()

--- Draws the ESP of one player: names, an outline box, health and armor bars.
-- @param target [Player]
-- @param client_pos [Vector position of the local player]
-- @param teams [Map team data by team index]
-- @param font_small [String font of the name]
-- @param font_smaller [String font of the Steam name and of the death mark]
local function draw_target(target, client_pos, teams, font_small, font_smaller)
  local pos = target:GetPos()
  local screen_pos = pos:ToScreen()

  offset_pos:Set(pos)
  offset_pos.z = pos.z + 60

  local head_pos = offset_pos:ToScreen()

  offset_pos.z = pos.z + 90

  local text_pos = offset_pos:ToScreen()
  local text_x, text_y = text_pos.x, text_pos.y
  local x, y = head_pos.x, head_pos.y
  local size = 52 * 350 / max(client_pos:Distance(pos), 1)
  local half_size = size * 0.5
  local box_height = (screen_pos.y - y) * 1.25
  local team_info = teams[target:Team()]
  local team_color = team_info and team_info.Color or color_fallback
  local name = target:name()
  local steam_name = target:steam_name()

  draw_simple_text(name, font_small, text_x - text_size(name, font_small) * 0.5, text_y, team_color)
  draw_simple_text(
    steam_name,
    font_smaller,
    text_x - text_size(steam_name, font_smaller) * 0.5,
    text_y + 14,
    color_lightblue
  )

  if target:Alive() then
    set_draw_color(team_color)
    draw_outlined_rect(x - half_size, y - half_size, size, box_height)
  else
    local text = t'ui.hud.dead'

    draw_simple_text(text, font_smaller, text_x - text_size(text, font_smaller) * 0.5, text_y + 28, color_lightred)
  end

  local bx, by = x - half_size, y - half_size + box_height
  local health = clamp((target:Health() or 0) / target:GetMaxHealth(), 0, 1)

  if health > 0 then
    draw_rounded_box(0, bx, by, size, 2, color_grey)
    draw_rounded_box(0, bx, by, size * health, 2, color_red)
  end

  local armor = clamp((target:Armor() or 0) * 0.01, 0, 1)

  if armor > 0 then
    draw_rounded_box(0, bx, by + 3, size, 2, color_grey)
    draw_rounded_box(0, bx, by + 3, size * armor, 2, color_blue)
  end
end

--- Draws the admin ESP for every player but the local one.
-- @param client [Player the local player]
function Observer:draw_esp(client)
  local client_pos = client:GetPos()
  local teams = get_all_teams()
  local font_small = get_font('text_small')
  local font_smaller = get_font('text_smaller')

  for _, target in player_iterator() do
    if target != client then
      draw_target(target, client_pos, teams, font_small, font_smaller)
    end
  end
end

--- Takes the ESP colors from a theme.
-- @param current_theme [ThemeBase the loaded theme]
function Observer:set_esp_colors(current_theme)
  color_red = current_theme:get_color('esp_red')
  color_blue = current_theme:get_color('esp_blue')
  color_grey = current_theme:get_color('esp_grey')
  color_lightred = color_red:lighten(100)
  color_lightblue = color_blue:lighten(200)
end
