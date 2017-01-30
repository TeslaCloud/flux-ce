--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

-- Create the default theme that other themes will derive from.
local THEME = Theme("Factory");
THEME.author = "TeslaCloud Studios"
THEME.uniqueID = "factory";
THEME.shouldReload = true;

function THEME:OnLoaded()
	self:AddPanel("TabMenu", function(id, parent, ...)
		return vgui.Create("reTabMenu", parent);
	end);

	self:AddPanel("MainMenu", function(id, parent, ...)
		return vgui.Create("reMainMenu", parent);
	end);
end;

function THEME:CreateMainMenu(panel)
end;

function THEME:PaintFrame(panel, width, height)
	surface.SetDrawColor(panel:GetAccentColor());
	surface.DrawOutlinedRect(0, 0, width, height);
	surface.DrawRect(1, 1, width - 2, 20);

	surface.SetDrawColor(panel.m_MainColor);
	surface.DrawRect(1, 20, width - 2, height - 21);

	local title = panel:GetTitle();

	if (title) then
		draw.SimpleText(title, "rw_frame_title", 6, 4, panel:GetTextColor());
	end;
end;

function THEME:DrawBarBackground(barInfo)
	draw.RoundedBox(barInfo.cornerRadius, barInfo.x, barInfo.y, barInfo.width, barInfo.height, Color(40, 40, 40));

	return true; -- returning true overrides default code (if any).
end;

function THEME:DrawBarHindrance(barInfo)
	local length = barInfo.width * (barInfo.hinderValue / barInfo.maxValue);

	draw.RoundedBox(barInfo.cornerRadius, barInfo.x + barInfo.width - length - 1, barInfo.y + 1, length, barInfo.height - 2, barInfo.hinderColor);

	return true;
end;

function THEME:DrawBarFill(barInfo)
	draw.RoundedBox(barInfo.cornerRadius, barInfo.x + 1, barInfo.y + 1, (barInfo.fillWidth or barInfo.width) - 2, barInfo.height - 2, barInfo.color);

	return true;
end;

function THEME:DrawBarTexts(barInfo)
	draw.SimpleText(barInfo.text, barInfo.font, barInfo.x + 8, barInfo.y + barInfo.textOffset, Color(255, 255, 255));

	if (barInfo.hinderDisplay and barInfo.hinderDisplay <= barInfo.hinderValue) then
		local width = barInfo.width;
		local textWide = util.GetTextSize(barInfo.hinderText, barInfo.font);
		local length = width * (barInfo.hinderValue / barInfo.maxValue);

		render.SetScissorRect(barInfo.x + width - length, barInfo.y, barInfo.x + width, barInfo.y + barInfo.height, true);
			draw.SimpleText(barInfo.hinderText, barInfo.font, barInfo.x + width - textWide - 8, barInfo.y + barInfo.textOffset, Color(255, 255, 255));
		render.SetScissorRect(0, 0, 0, 0, false);
	end;

	return true;
end;

THEME:Register();