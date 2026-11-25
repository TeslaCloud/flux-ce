--- Client side of the Stamina plugin: draws the stamina bar on the HUD.

local IsValid = IsValid
local Lerp = Lerp
local FrameTime = FrameTime

local w, h = math.scale(512), math.scale(4)
local y_offset = math.scale(300)
local cur_wide = w
local cur_alpha = 0
local max_stamina = Config.get('stamina_max', 100)
local full_color = Color(0, 225, 0)
local empty_color = Color(200, 0, 0)
local shadow_color = Color(0, 0, 0, 0)
local bar_color = Color(0, 0, 0, 0)

--- Keeps the cached 'stamina_max' config in sync with the value the server has sent.
-- @param key [String config key]
-- @param _old_value [Any]
-- @param _new_value [Any]
function Stamina:ConfigReceived(key, _old_value, _new_value)
  if key == 'stamina_max' then
    max_stamina = Config.get('stamina_max', 100)
  end
end

--- Draws the stamina bar, which fades in while stamina is below 98% of the 'stamina_max'
-- config and out otherwise, and draws nothing once it has faded out.
-- The theme can take over the drawing through its PaintStaminaBar hook.
function Stamina:HUDPaint()
  local client = PLAYER

  if !IsValid(client) or !client:Alive() then return end

  local stamina = client:get_nv('stamina', max_stamina)
  local frame_time = FrameTime() * 8
  local percentage = stamina / math.max(max_stamina, 1)

  cur_alpha = Lerp(frame_time, cur_alpha, percentage < 0.98 ? 1 : 0)

  if cur_alpha < 0.01 then return end

  if Theme.hook('PaintStaminaBar', stamina, percentage, cur_alpha, frame_time) != nil then return end

  local cx, cy = ScrC()
  local gx, gy = Flux.global_ui_offset()
  local x, y = gx + cx - w * 0.5, gy + cy - h * 0.5 + y_offset
  local fraction = 1 - percentage

  cur_wide = Lerp(frame_time, cur_wide, w * percentage)

  shadow_color.a = 160 * cur_alpha

  bar_color.r = Lerp(fraction, full_color.r, empty_color.r)
  bar_color.g = Lerp(fraction, full_color.g, empty_color.g)
  bar_color.b = Lerp(fraction, full_color.b, empty_color.b)
  bar_color.a = 200 * cur_alpha

  draw.textured_rect(Theme.get_material('gradient'), x - 2, y - 2, w + 4, h + 4, shadow_color)
  draw.RoundedBox(0, x, y, cur_wide, h, bar_color)
end
