PLUGIN:set_name("Admin ESP")
PLUGIN:set_author("Mr. Meow")
PLUGIN:set_description("Adds an ESP for admins.")

do
  local color_lightred = Color(255, 100, 100)
  local color_lightblue = Color(200, 200, 255)
  local color_grey = Color(100, 100, 100)
  local color_red = Color(255, 0, 0)
  local color_blue = Color(0, 0, 255)

  function PLUGIN:OnThemeLoaded(current_theme)
    color_red = current_theme:GetColor("ESP_Red")
    color_blue = current_theme:GetColor("ESP_Blue")
    color_grey = current_theme:GetColor("ESP_Grey")
    color_lightred = color_red:lighten(100)
    color_lightblue = color_blue:lighten(200)
  end

  function PLUGIN:HUDPaint()
    if (IsValid(fl.client) and fl.client:Alive() and fl.client:GetMoveType() == MOVETYPE_NOCLIP and fl.client:HasPermission("admin_esp")) then
      local scrW, scrH = ScrW(), ScrH()
      local clientPos = fl.client:GetPos()

      for k, v in ipairs(_player.GetAll()) do
        if (v == fl.client) then continue end

        local pos = v:GetPos()
        local head = Vector(pos.x, pos.y, pos.z + 60)
        local screenPos = pos:ToScreen()
        local headPos = head:ToScreen()
        local textPos = Vector(head.x, head.y, head.z + 30):ToScreen()
        local x, y = headPos.x, headPos.y
        local size = 52 * math.abs(350 / clientPos:Distance(pos))
        local teamColor = team.GetColor(v:Team()) or Color(255, 255, 255)

        local w, h = util.text_size(v:Name(), theme.GetFont("Text_Small"))
        draw.SimpleText(v:Name(), theme.GetFont("Text_Small"), textPos.x - w * 0.5, textPos.y, teamColor)

        local w, h = util.text_size(v:SteamName(), theme.GetFont("Text_Smaller"))
        draw.SimpleText(v:SteamName(), theme.GetFont("Text_Smaller"), textPos.x - w * 0.5, textPos.y + 14, color_lightblue)

        if (v:Alive()) then
          surface.SetDrawColor(teamColor)
          surface.DrawOutlinedRect(x - size * 0.5, y - size * 0.5, size, (screenPos.y - y) * 1.25)
        else
          local w, h = util.text_size("*DEAD*", theme.GetFont("Text_Smaller"))
          draw.SimpleText("*DEAD*", theme.GetFont("Text_Smaller"), textPos.x - w * 0.5, textPos.y + 28, color_lightred)
        end

        local bx, by = x - size * 0.5, y - size * 0.5 + (screenPos.y - y) * 1.25
        local hpM = math.Clamp((v:Health() or 0) / v:GetMaxHealth(), 0, 1)

        if (hpM > 0) then
          draw.RoundedBox(0, bx, by, size, 2, color_grey)
          draw.RoundedBox(0, bx, by, size * hpM, 2, color_red)
        end

        local arM = math.Clamp((v:Armor() or 0) / 100, 0, 1)

        if (arM > 0) then
          draw.RoundedBox(0, bx, by + 3, size, 2, color_grey)
          draw.RoundedBox(0, bx, by + 3, size * arM, 2, color_blue)
        end
      end
    end
  end
end
