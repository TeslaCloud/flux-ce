--- The color modification of the local player's screen, the one color correction pass of the
-- Screen Effects plugin. A schema gives the game its own look with it: `Flux.enable_color_mod`
-- turns that look on, `Flux.disable_color_mod` turns it off, and `Flux.set_color_mod` and
-- `Flux.set_color_mod_table` set its values, which are those of GMod's `DrawColorModify`.
-- The saturation, brightness and contrast of the effects are folded into the look every
-- frame by `ScreenEffects:draw_color_mod`, so the screen is only color corrected once.
-- ```
-- function SCHEMA:PostInitPostEntity()
--   Flux.enable_color_mod()
--   Flux.set_color_mod('color', 0.85)
-- end
-- ```

if !ScreenEffects then
  PLUGIN:set_global('ScreenEffects')
end

const default_color_mod = {
  ['$pp_colour_addr'] = 0,
  ['$pp_colour_addg'] = 0,
  ['$pp_colour_addb'] = 0,
  ['$pp_colour_brightness'] = 0,
  ['$pp_colour_contrast'] = 1,
  ['$pp_colour_colour'] = 1,
  ['$pp_colour_mulr'] = 0,
  ['$pp_colour_mulg'] = 0,
  ['$pp_colour_mulb'] = 0
}

local color_mod = ScreenEffects.color_mod or table.Copy(default_color_mod)
local drawn = ScreenEffects.drawn_color_mod or table.Copy(default_color_mod)
ScreenEffects.color_mod = color_mod
ScreenEffects.drawn_color_mod = drawn

--- Turns the color modification of the local player's screen on.
function Flux.enable_color_mod()
  ScreenEffects.color_mod_enabled = true
end

--- Turns the color modification of the local player's screen off. The effects of the plugin
-- still color the screen while they change the picture.
function Flux.disable_color_mod()
  ScreenEffects.color_mod_enabled = false
end

--- Sets one value of the color modification. The '$pp_colour_' prefix may be left out and
-- 'color' is accepted in place of 'colour'.
-- ```
-- Flux.set_color_mod('contrast', 1.2)
-- Flux.set_color_mod('$pp_colour_addr', 0.1)
-- ```
-- @param index [String DrawColorModify key, with or without the '$pp_colour_' prefix;
--   anything that is not a string is ignored]
-- @param value [Number new value; anything that is not a number is stored as 0]
function Flux.set_color_mod(index, value)
  if !isstring(index) then return end

  if !index:start_with('$pp_colour_') then
    index = '$pp_colour_'..(index == 'color' ? 'colour' : index)
  end

  color_mod[index] = isnumber(value) and value or 0
end

--- Replaces every value of the color modification. A key that the table leaves out goes back
-- to its default. Does nothing if tab is not a table.
-- @param tab [Map '$pp_colour_*' keys and their values, as accepted by DrawColorModify]
function Flux.set_color_mod_table(tab)
  if !istable(tab) then return end

  for key, value in pairs(default_color_mod) do
    color_mod[key] = isnumber(tab[key]) and tab[key] or value
  end
end

--- Draws the color modification with the color pass of the effects folded in: the
-- saturation and the contrast multiply those of the schema's look and the brightness is
-- added to it. Draws nothing while the color modification is off and the pass leaves the
-- picture alone.
-- @param saturation [Number 1 leaves the colors alone]
-- @param brightness [Number 0 leaves it alone]
-- @param contrast [Number 1 leaves it alone]
function ScreenEffects:draw_color_mod(saturation, brightness, contrast)
  if !self.color_mod_enabled and saturation == 1 and brightness == 0 and contrast == 1 then return end

  for key, value in pairs(color_mod) do
    drawn[key] = value
  end

  drawn['$pp_colour_colour'] = color_mod['$pp_colour_colour'] * saturation
  drawn['$pp_colour_brightness'] = color_mod['$pp_colour_brightness'] + brightness
  drawn['$pp_colour_contrast'] = color_mod['$pp_colour_contrast'] * contrast

  DrawColorModify(drawn)
end
