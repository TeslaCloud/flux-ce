--- Client-side functions of the Limbs plugin: the colors of hurt limbs and the body diagram,
-- which is drawn from rounded boxes and needs no materials. The colors of the diagram of
-- the local player are only worked out again when the damage of a limb or the opacity of
-- the diagram changes, or the theme is loaded again.

local healthy_color = Color(166, 243, 76)
local hurt_color = Color(233, 201, 94)
local critical_color = Color(222, 57, 57)
local background_color = Color(0, 0, 0)

--- Colors of the diagram of the local player as they were last drawn, by limb ID and
-- 'background': the damage and the alpha each was worked out for, and the color.
local cached_colors = {}

local diagram_width = 60
local diagram_height = 120

local shapes = {
  { limb = 'head', x = 21, y = 0, w = 18, h = 18, rounding = 9 },
  { limb = 'chest', x = 16, y = 20, w = 28, h = 28, rounding = 4 },
  { limb = 'stomach', x = 18, y = 50, w = 24, h = 18, rounding = 4 },
  { limb = 'left_arm', x = 4, y = 20, w = 10, h = 46, rounding = 4 },
  { limb = 'right_arm', x = 46, y = 20, w = 10, h = 46, rounding = 4 },
  { limb = 'left_leg', x = 18, y = 70, w = 11, h = 50, rounding = 4 },
  { limb = 'right_leg', x = 31, y = 70, w = 11, h = 50, rounding = 4 }
}

--- Returns the color that stands for an amount of limb damage: it goes from the
-- 'limb_healthy' color of the theme through 'limb_hurt' at half damage to 'limb_critical'.
-- The plugin has defaults for all three (green, yellow and red).
-- @param damage [Number limb damage from 0 to 100]
-- @return [Color]
function Limbs:get_color(damage)
  local fraction = math.Clamp((tonumber(damage) or 0) / self.max_damage, 0, 1)
  local hurt = Theme.get_color('limb_hurt', hurt_color)

  if fraction <= 0.5 then
    return LerpColor(fraction * 2, Theme.get_color('limb_healthy', healthy_color), hurt)
  end

  return LerpColor((fraction - 0.5) * 2, hurt, Theme.get_color('limb_critical', critical_color))
end

--- Returns the color of a limb of the local player for a damage and an opacity, working it
-- out only when either has changed since the last time.
-- @param limb [String limb ID, or 'background' for the background of the diagram]
-- @param damage [Number limb damage from 0 to 100; ignored for the background]
-- @param alpha [Number alpha from 0 to 255]
-- @return [Color do not modify the color]
local function get_cached_color(limb, damage, alpha)
  local cached = cached_colors[limb]

  if cached and cached.damage == damage and cached.alpha == alpha then
    return cached.color
  end

  local color

  if limb == 'background' then
    color = Theme.get_color('limbs_background', background_color):alpha(alpha)
  else
    color = Limbs:get_color(damage):alpha(alpha)
  end

  cached_colors[limb] = { damage = damage, alpha = alpha, color = color }

  return color
end

--- Forgets the colors the diagram of the local player was last drawn with, so that they
-- are worked out again from the theme on the next frame.
function Limbs:reset_colors()
  cached_colors = {}
end

--- Returns when the local player wants to see the body diagram on the HUD: the value of
-- the 'limbs_hud' client setting, or 'hurt' when the Settings plugin is not loaded.
-- @return [String 'hurt' (while any limb is hurt), 'always' or 'never']
function Limbs:get_hud_mode()
  if ClientSettings then
    return ClientSettings:get('limbs_hud', 'hurt')
  end

  return 'hurt'
end

--- Draws the body diagram: a figure seen from behind, so its left limbs are on the left,
-- on a dark background ('limbs_background' color of the theme), with every limb in the
-- color of its damage. The figure is half as wide as it is tall.
-- ```
-- -- The limbs of the local player, 256 pixels tall.
-- Limbs:draw_diagram(32, 32, 256)
--
-- -- Any other set of limbs.
-- Limbs:draw_diagram(32, 32, 256, 1, { head = 20, left_leg = 80 })
-- ```
-- @param x [Number left edge of the figure]
-- @param y [Number top edge of the figure]
-- @param height [Number height of the figure in pixels]
-- @param alpha=1 [Number opacity from 0 to 1]
-- @param limbs=nil [Map damage by limb ID; the limbs of the local player when omitted,
--   whose colors are kept between frames]
-- @see [Limbs:get_color]
function Limbs:draw_diagram(x, y, height, alpha, limbs)
  alpha = alpha or 1

  local own = limbs == nil

  limbs = limbs or self:get_all_damage(PLAYER)

  local scale = height / diagram_height
  local padding = math.ceil(8 * scale)
  local background_alpha = 120 * alpha
  local limb_alpha = 220 * alpha

  draw.RoundedBox(
    padding,
    math.floor(x - padding),
    math.floor(y - padding),
    math.ceil(diagram_width * scale + padding * 2),
    math.ceil(height + padding * 2),
    own and get_cached_color('background', 0, background_alpha)
      or Theme.get_color('limbs_background', background_color):alpha(background_alpha)
  )

  for k, v in ipairs(shapes) do
    local damage = limbs[v.limb] or 0

    draw.RoundedBox(
      math.floor(v.rounding * scale),
      math.floor(x + v.x * scale),
      math.floor(y + v.y * scale),
      math.ceil(v.w * scale),
      math.ceil(v.h * scale),
      own and get_cached_color(v.limb, damage, limb_alpha) or self:get_color(damage):alpha(limb_alpha)
    )
  end
end
