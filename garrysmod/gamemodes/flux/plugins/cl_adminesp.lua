--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

PLUGIN:SetName("Admin ESP")
PLUGIN:SetAuthor("Mr. Meow")
PLUGIN:SetDescription("Adds an ESP for admins.")

function PLUGIN:HUDPaint()
	if (IsValid(fl.client) and fl.client:Alive() and fl.client:IsOperator() and fl.client:GetMoveType() == MOVETYPE_NOCLIP) then
		local scrW, scrH = ScrW(), ScrH()

		for k, v in ipairs(_player.GetAll()) do
			if (v == fl.client) then continue end

			local pos = v:GetPos()
			local head = Vector(pos.x, pos.y, pos.z + 60)
			local screenPos = pos:ToScreen()
			local headPos = head:ToScreen()
			local textPos = Vector(head.x, head.y, head.z + 30):ToScreen()
			local distance = fl.client:GetPos():Distance(v:GetPos())
			local x, y = headPos.x, headPos.y
			local f = math.abs(350 / distance)
			local size = 52 * f
			local teamColor = team.GetColor(v:Team()) or Color(255, 255, 255)

			local w, h = util.GetTextSize(v:Name(), theme.GetFont("Text_Small"))
			draw.SimpleText(v:Name(), theme.GetFont("Text_Small"), textPos.x - w / 2, textPos.y, teamColor)

			local w, h = util.GetTextSize(v:SteamName(), theme.GetFont("Text_Smaller"))
			draw.SimpleText(v:SteamName(), theme.GetFont("Text_Smaller"), textPos.x - w / 2, textPos.y + 14, Color(200, 200, 255))

			if (v:Alive()) then
				surface.SetDrawColor(teamColor)
				surface.DrawOutlinedRect(x - size / 2, y - size / 2, size, (screenPos.y - y) * 1.25)
			else
				local w, h = util.GetTextSize("*DEAD*", theme.GetFont("Text_Smaller"))
				draw.SimpleText("*DEAD*", theme.GetFont("Text_Smaller"), textPos.x - w / 2, textPos.y + 28, Color(255, 100, 100))
			end

			local bx, by = x - size / 2, y - size / 2 + (screenPos.y - y) * 1.25
			local hpM = math.Clamp((v:Health() or 0) / v:GetMaxHealth(), 0, 1)

			if (hpM > 0) then
				draw.RoundedBox(0, bx, by, size, 2, Color(100, 100, 100))
				draw.RoundedBox(0, bx, by, size * hpM, 2, Color(255, 0, 0))
			end

			local arM = math.Clamp((v:Armor() or 0) / 100, 0, 1)

			if (arM > 0) then
				draw.RoundedBox(0, bx, by + 3, size, 2, Color(100, 100, 100))
				draw.RoundedBox(0, bx, by + 3, size * arM, 2, Color(0, 0, 255))
			end
		end
	end
end