PLUGIN:set_name('Color Modify')
PLUGIN:set_author('TeslaCloud Studios')
PLUGIN:set_description('Provides a color modify API.')

do
  local default_color_mod = {
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

  --- Turns the local player's color modification effect on or off.
  -- Gives the player the default color modification table if they have none yet.
  -- @param enable [Boolean whether the effect should be drawn]
  -- @return [Boolean true when enabling, nil when disabling]
  function Flux.color_mod_enabled(enable)
    if !PLAYER.color_mod_table then
      PLAYER.color_mod_table = default_color_mod
    end

    if enable then
      PLAYER.color_mod = true
      return true
    end

    PLAYER.color_mod = false
  end

  --- Turns the local player's color modification effect on.
  -- @return [Boolean always true]
  -- @see [Flux.color_mod_enabled]
  function enable_color_mod()
    return Flux.color_mod_enabled(true)
  end

  --- Turns the local player's color modification effect off.
  -- @see [Flux.color_mod_enabled]
  function Flux.disable_color_mod()
    return Flux.color_mod_enabled(false)
  end

  --- Sets one value of the local player's color modification table.
  -- The '$pp_colour_' prefix may be left out and 'color' is accepted in place of 'colour'.
  -- ```
  -- Flux.set_color_mod('contrast', 1.2)
  -- Flux.set_color_mod('$pp_colour_addr', 0.1)
  -- ```
  -- @param index [String DrawColorModify key, with or without the '$pp_colour_' prefix;
  --   anything that is not a string is ignored]
  -- @param value [Number new value; anything that is not a number is stored as 0]
  function Flux.set_color_mod(index, value)
    if !PLAYER.color_mod_table then
      PLAYER.color_mod_table = default_color_mod
    end

    if isstring(index) then
      if !index:start_with('$pp_colour_') then
        if index == 'color' then index = 'colour' end

        PLAYER.color_mod_table['$pp_colour_'..index] = (isnumber(value) and value) or 0
      else
        PLAYER.color_mod_table[index] = (isnumber(value) and value) or 0
      end
    end
  end

  --- Replaces the local player's whole color modification table.
  -- Does nothing if tab is not a table.
  -- @param tab [Map '$pp_colour_*' keys and their values, as accepted by DrawColorModify]
  function Flux.set_color_mod_table(tab)
    if istable(tab) then
      PLAYER.color_mod_table = tab
    end
  end
end

--- Draws the local player's color modification table while the effect is enabled.
function PLUGIN:RenderScreenspaceEffects()
  if IsValid(PLAYER) and PLAYER.color_mod then
    DrawColorModify(PLAYER.color_mod_table)
  end
end
