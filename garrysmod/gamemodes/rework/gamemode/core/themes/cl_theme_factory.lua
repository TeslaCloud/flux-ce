--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

// Create the default theme that other themes will derive from.
local THEME = Theme("Factory");
THEME.author = "TeslaCloud Studios"

function THEME:OnLoaded()
	if (rw.settings:GetBool("UseTabDash")) then
		self:AddPanel("TabMenu", function(id, parent, ...)
			return vgui.Create("rwTabDash", parent);
		end);
	else
		self:AddPanel("TabMenu", function(id, parent, ...)
			return vgui.Create("rwTabClassic", parent);
		end);
	end;

	self:AddPanel("MainMenu", function(id, parent, ...)
		return vgui.Create("rwMainMenu", parent);
	end);
end;

function THEME:DrawBarBackground(barInfo)
	draw.RoundedBox(barInfo.cornerRadius, barInfo.x, barInfo.y, barInfo.width, barInfo.height, Color(40, 40, 40));

	return true; -- returning true overrides default code.
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