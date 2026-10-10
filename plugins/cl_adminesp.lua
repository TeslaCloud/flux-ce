--- Admin ESP shows staff where the other players are while they are noclipping.
-- For every other player it draws their name and Steam name, an outline box and health and
-- armor bars, visible through walls. It is only drawn for players with the 'admin_esp'
-- permission, which the plugin registers for moderators, and its colors come from the
-- `esp_red`, `esp_blue` and `esp_grey` colors of the theme.

local draw_simple_text = draw.SimpleText
local draw_rounded_box = draw.RoundedBox
local text_size = util.text_size
local clamp = math.Clamp

PLUGIN:set_name('Admin ESP')
PLUGIN:set_author('TeslaCloud Studios')
PLUGIN:set_description('Adds an ESP for admins.')

--- Registers the 'admin_esp' permission, allowed for moderators by default. The plugin only
-- exists on the client, which is also the only place where the permission is checked.
function PLUGIN:RegisterPermissions()
  Bolt:register_permission(
    'admin_esp',
    'Admin ESP',
    'Grants access to see the other players through walls while noclipping.',
    'permission.categories.administration',
    'moderator'
  )
end

do
  local color_lightred = Color(255, 100, 100)
  local color_lightblue = Color(200, 200, 255)
  local color_grey = Color(100, 100, 100)
  local color_red = Color(255, 0, 0)
  local color_blue = Color(0, 0, 255)
  local color_fallback = Color(255, 255, 255)

  --- Draws the admin ESP for every other player: names, an outline box, health and armor bars.
  -- Only drawn while the local player is noclipping and has the 'admin_esp' permission.
  function PLUGIN:HUDPaint()
    if IsValid(PLAYER) and PLAYER:Alive() and PLAYER:GetMoveType() == MOVETYPE_NOCLIP and can('admin_esp')
    and !PLAYER:InVehicle() then
      local client_pos = PLAYER:GetPos()
      local font_small = Theme.get_font('text_small')
      local font_smaller = Theme.get_font('text_smaller')

      for k, v in player.Iterator() do
        if v == PLAYER then continue end

        local pos = v:GetPos()
        local screen_pos = pos:ToScreen()
        local head_pos = Vector(pos.x, pos.y, pos.z + 60):ToScreen()
        local text_pos = Vector(pos.x, pos.y, pos.z + 90):ToScreen()
        local text_x, text_y = text_pos.x, text_pos.y
        local x, y = head_pos.x, head_pos.y
        local size = 52 * math.abs(350 / client_pos:Distance(pos))
        local half_size = size * 0.5
        local box_height = (screen_pos.y - y) * 1.25
        local team_color = team.GetColor(v:Team()) or color_fallback
        local name = v:name()
        local steam_name = v:steam_name()

        draw_simple_text(name, font_small, text_x - text_size(name, font_small) * 0.5, text_y, team_color)
        draw_simple_text(
          steam_name,
          font_smaller,
          text_x - text_size(steam_name, font_smaller) * 0.5,
          text_y + 14,
          color_lightblue
        )

        if v:Alive() then
          surface.SetDrawColor(team_color)
          surface.DrawOutlinedRect(x - half_size, y - half_size, size, box_height)
        else
          local text = t'ui.hud.dead'

          draw_simple_text(
            text,
            font_smaller,
            text_x - text_size(text, font_smaller) * 0.5,
            text_y + 28,
            color_lightred
          )
        end

        local bx, by = x - half_size, y - half_size + box_height
        local health = clamp((v:Health() or 0) / v:GetMaxHealth(), 0, 1)

        if health > 0 then
          draw_rounded_box(0, bx, by, size, 2, color_grey)
          draw_rounded_box(0, bx, by, size * health, 2, color_red)
        end

        local armor = clamp((v:Armor() or 0) * 0.01, 0, 1)

        if armor > 0 then
          draw_rounded_box(0, bx, by + 3, size, 2, color_grey)
          draw_rounded_box(0, bx, by + 3, size * armor, 2, color_blue)
        end
      end
    end
  end

  --- Refreshes the ESP colors from the theme that has just been loaded.
  -- @param current_theme [ThemeBase the loaded theme]
  function PLUGIN:OnThemeLoaded(current_theme)
    color_red = current_theme:get_color('esp_red')
    color_blue = current_theme:get_color('esp_blue')
    color_grey = current_theme:get_color('esp_grey')
    color_lightred = color_red:lighten(100)
    color_lightblue = color_blue:lighten(200)
  end
end
