--- Crosshair draws a dynamic crosshair: a center dot with four bars whose gap widens with the
-- distance to what the player is aiming at.
-- It is hidden while the player is running or dead, and whenever the `ShouldHUDPaint` or
-- `ShouldHUDPaintCrosshair` hook returns false. Plugins change its color and gap through the
-- `AdjustCrosshairColor` and `AdjustCrosshairGap` hooks; the plugin itself uses them to tint
-- and narrow the crosshair when the player aims at a nearby player or item.

PLUGIN:set_name('Crosshair')
PLUGIN:set_author('TeslaCloud Studios')
PLUGIN:set_description('Adds a crosshair.')

local size = math.scale(2)
local half_size = size * 0.5
local double_size = size * 2
local gap = math.scale(8)
local cur_gap = gap

--- Hides the crosshair while the local player is running, dead or not yet initialized.
-- @return [Boolean false to hide the crosshair, nil otherwise]
function PLUGIN:ShouldHUDPaintCrosshair()
  if PLAYER:running() or !PLAYER:Alive() or !PLAYER:has_initialized() then
    return false
  end
end

--- Draws the crosshair: a center dot and four bars around it.
-- Gap and color can be changed through the AdjustCrosshairGap and AdjustCrosshairColor hooks.
function PLUGIN:HUDPaint()
  --- Flux's `ShouldHUDPaint` hook, asked again here before the crosshair is drawn, so that
  -- whatever hides the HUD hides the crosshair as well.
  -- Called on the client on every HUD paint. The same condition then runs
  -- `ShouldHUDPaintCrosshair`, which takes no arguments either and hides only the crosshair
  -- when a handler returns false.
  -- @return [Boolean Return false to hide the HUD and the crosshair with it]
  if IsValid(PLAYER) and hook.Run('ShouldHUDPaint') != false and hook.Run('ShouldHUDPaintCrosshair') != false then
    local lerp_step = FrameTime() * 6
    local trace = PLAYER:GetEyeTraceNoCursor()
    local distance = PLAYER:GetPos():Distance(trace.HitPos)
    --- Lets plugins change the color of the crosshair.
    -- Called on the client on every frame the crosshair is drawn.
    -- @param trace [Map Trace result of the local player's aim]
    -- @param distance [Number Distance from the local player to the hit position of the trace]
    -- @return [Color Color to draw the crosshair in; white when nothing is returned]
    local draw_color = Plugin.call('AdjustCrosshairColor', trace, distance) or color_white
    local secondary_draw_color = draw_color:alpha(25)
    local real_gap =
      --- Lets plugins change the gap between the center of the crosshair and its bars.
      -- Called on the client on every frame the crosshair is drawn.
      -- @param trace [Map Trace result of the local player's aim]
      -- @param distance [Number Distance from the local player to the hit position of the trace]
      -- @return [Number Gap in pixels; when nothing is returned the gap grows with the
      --   distance]
      Plugin.call('AdjustCrosshairGap', trace, distance) or math.Round(gap * math.Clamp(distance / 400, 0.5, 4))
    cur_gap = Lerp(lerp_step, cur_gap, real_gap)

    if math.abs(cur_gap - real_gap) < 0.5 then
      cur_gap = real_gap
    end

    if draw_color != color_white then
      secondary_draw_color = secondary_draw_color:alpha(255)
    end

    local scrw, scrh = ScrW(), ScrH()
    local gox, goy = Flux.global_ui_offset()

    draw.RoundedBox(0, gox + (scrw * 0.5 - half_size), goy + (scrh * 0.5 - half_size), size, size, draw_color)

    draw.RoundedBox(
      0,
      gox + (scrw * 0.5 - half_size - cur_gap),
      goy + (scrh * 0.5 - size),
      size,
      double_size,
      secondary_draw_color
    )
    draw.RoundedBox(
      0,
      gox + (scrw * 0.5 - half_size + cur_gap),
      goy + (scrh * 0.5 - size),
      size,
      double_size,
      secondary_draw_color
    )

    draw.RoundedBox(
      0,
      gox + (scrw * 0.5 - size),
      goy + (scrh * 0.5 - half_size - cur_gap),
      double_size,
      size,
      secondary_draw_color
    )
    draw.RoundedBox(
      0,
      gox + (scrw * 0.5 - size),
      goy + (scrh * 0.5 - half_size + cur_gap),
      double_size,
      size,
      secondary_draw_color
    )
  end
end

--- Tints the crosshair with the theme's accent color when the local player aims at a player
-- or an item that is less than 600 units away.
-- @param trace [Map trace result of the local player's aim]
-- @param distance [Number distance from the local player to the trace hit position]
-- @return [Color the accent color, or nil to keep the default color]
function PLUGIN:AdjustCrosshairColor(trace, distance)
  local ent = trace.Entity

  if distance < 600 and IsValid(ent) and (ent:IsPlayer() or ent:GetClass() == 'fl_item') then
    return Theme.get_color('accent')
  end
end

--- Narrows the crosshair when the local player aims at a player or an item that is less than
-- 600 units away.
-- @param trace [Map trace result of the local player's aim]
-- @param distance [Number distance from the local player to the trace hit position]
-- @return [Number a gap of 8, or nil to keep the distance-based gap]
function PLUGIN:AdjustCrosshairGap(trace, distance)
  local ent = trace.Entity

  if distance < 600 and IsValid(ent) and (ent:IsPlayer() or ent:GetClass() == 'fl_item') then
    return 8
  end
end
