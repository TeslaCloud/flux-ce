PLUGIN:set_name('Admin ESP')
PLUGIN:set_author('TeslaCloud Studios')
PLUGIN:set_description('Adds an ESP for admins.')

do
  local color_lightred = Color(255, 100, 100)
  local color_lightblue = Color(200, 200, 255)
  local color_grey = Color(100, 100, 100)
  local color_red = Color(255, 0, 0)
  local color_blue = Color(0, 0, 255)

  function PLUGIN:HUDPaint()
    if IsValid(PLAYER) and PLAYER:Alive() and PLAYER:GetMoveType() == MOVETYPE_NOCLIP and can('admin_esp')
    and !PLAYER:InVehicle() then
      local clientPos = PLAYER:GetPos()

      for k, v in ipairs(_player.GetAll()) do
        if v == PLAYER then continue end

        local pos = v:GetPos()
        local head = Vector(pos.x, pos.y, pos.z + 60)
        local screen_pos = pos:ToScreen()
        local head_pos = head:ToScreen()
        local text_pos = Vector(head.x, head.y, head.z + 30):ToScreen()
        local x, y = head_pos.x, head_pos.y
        local size = 52 * math.abs(350 / clientPos:Distance(pos))
        local team_color = team.GetColor(v:Team()) or Color(255, 255, 255)

        local w, h = util.text_size(v:name(), Theme.get_font('text_small'))
        draw.SimpleText(v:name(), Theme.get_font('text_small'), text_pos.x - w * 0.5, text_pos.y, team_color)

        w, h = util.text_size(v:steam_name(), Theme.get_font('text_smaller'))
        draw.SimpleText(v:steam_name(), Theme.get_font('text_smaller'), text_pos.x - w * 0.5, text_pos.y + 14, color_lightblue)

        if v:Alive() then
          surface.SetDrawColor(team_color)
          surface.DrawOutlinedRect(x - size * 0.5, y - size * 0.5, size, (screen_pos.y - y) * 1.25)
        else
          w, h = util.text_size('*DEAD*', Theme.get_font('text_smaller'))
          draw.SimpleText('*DEAD*', Theme.get_font('text_smaller'), text_pos.x - w * 0.5, text_pos.y + 28, color_lightred)
        end

        local bx, by = x - size * 0.5, y - size * 0.5 + (screen_pos.y - y) * 1.25
        local health = math.Clamp((v:Health() or 0) / v:GetMaxHealth(), 0, 1)

        if health > 0 then
          draw.RoundedBox(0, bx, by, size, 2, color_grey)
          draw.RoundedBox(0, bx, by, size * health, 2, color_red)
        end

        local armor = math.Clamp((v:Armor() or 0) / 100, 0, 1)

        if armor > 0 then
          draw.RoundedBox(0, bx, by + 3, size, 2, color_grey)
          draw.RoundedBox(0, bx, by + 3, size * armor, 2, color_blue)
        end
      end
    end
  end

  function PLUGIN:OnThemeLoaded(current_theme)
    color_red = current_theme:get_color('esp_red')
    color_blue = current_theme:get_color('esp_blue')
    color_grey = current_theme:get_color('esp_grey')
    color_lightred = color_red:lighten(100)
    color_lightblue = color_blue:lighten(200)
  end
end
