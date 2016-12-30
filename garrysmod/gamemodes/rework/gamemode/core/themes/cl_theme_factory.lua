--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

// Create the default theme that other themes will derive from.
local THEME = Theme("Factory");
THEME.author = "TeslaCloud Studios"
THEME.uniqueID = "factory";
THEME.shouldReload = true;

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
		return vgui.Create("reMainMenu", parent);
	end);
end;

function THEME:CreateMainMenu(panel)
	panel:SetPos(0, 0);
	panel:SetSize(ScrW(), ScrH());

	local newText = L("#MainMenu_New");
	textW, textH = util.GetTextSize(newText, menuFont);

	panel.new = vgui.Create("reButton", panel);
	panel.new:SetSize(textW * 1.1, textH * 1.1);
	panel.new:SetPos(100, 70);
	panel.new:SetText(newText);
	panel.new:SetDrawBackground(false);
	panel.new:SetFont(rw.fonts:GetSize("menu_thin_large", 24));
	panel.new:SizeToContents();

	panel.new.DoClick = function(btn)
		panel.menu = vgui.Create("DFrame", panel);
		panel.menu:SetPos(ScrW() / 2 - 300, ScrH() / 4);
		panel.menu:SetSize(600, 600);
		panel.menu:SetTitle("CREATE CHARACTER");
		panel.menu:MakePopup();

		panel.NameEntry = vgui.Create("DTextEntry", panel.menu);
		panel.NameEntry:SetPos(8, 100);
		panel.NameEntry:SetSize(400, 32);
		panel.NameEntry:SetText("HOPE IT'S NOT 'TEST'");
		panel.NameEntry.OnEnter = function(entry)
			chat.AddText(Color("white"), "Creating character named: "..entry:GetValue());

			panel.menu:Remove();

			netstream.Start("rw_debug_createchar", entry:GetValue());
		end;
	end;

	local loadText = L("#MainMenu_Load");
	textW, textH = util.GetTextSize(loadText, "menu_thin_large");

	panel.load = vgui.Create("reButton", panel);
	panel.load:SetSize(textW * 1.1, textH * 1.1);
	panel.load:SetPos(100, 100);
	panel.load:SetText(loadText);
	panel.load:SetDrawBackground(false);
	panel.load:SetFont(rw.fonts:GetSize("menu_thin_large", 24));
	panel.load:SizeToContents();

	panel.load.DoClick = function(btn)
		panel.menu = vgui.Create("DFrame", panel);
		panel.menu:SetPos(ScrW() / 2 - 300, ScrH() / 4);
		panel.menu:SetSize(600, 600);
		panel.menu:SetTitle("LOAD CHARACTER");

		panel.menu.Paint = function(lp, w, h)
			draw.RoundedBox(0, 0, 0, w, h, Color(40, 40, 40));
			draw.SimpleText("Which one to load", "DermaLarge", 0, 24);

			if (#rw.client:GetAllCharacters() <= 0) then
				draw.SimpleText("wow you have none", "DermaLarge", 0, 24);
			end
		end;

		panel.menu:MakePopup();

		panel.menu.buttons = {};
		local offY = 0;

		for k, v in ipairs(rw.client:GetAllCharacters()) do
			panel.menu.buttons[k] = vgui.Create("DButton", panel.menu);
			panel.menu.buttons[k]:SetPos(8, 100 + offY);
			panel.menu.buttons[k]:SetSize(128, 24);
			panel.menu.buttons[k]:SetText(v.name);
			panel.menu.buttons[k].DoClick = function()
				netstream.Start("PlayerSelectCharacter", v.uniqueID);
				panel:Remove();
			end;

			offY = offY + 28
		end;
	end;

	if (rw.client:GetActiveCharacter()) then
		local cancelText = L("#MainMenu_Cancel");
		textW, textH = util.GetTextSize(cancelText, menuFont);
		
		panel.cancel = vgui.Create("reButton", panel);
		panel.cancel:SetSize(textW * 1.1, textH * 1.1);
		panel.cancel:SetPos(100, 130);
		panel.cancel:SetText(cancelText);
		panel.cancel:SetDrawBackground(false);
		panel.cancel:SetFont(rw.fonts:GetSize("menu_thin_large", 24));
		panel.cancel:SizeToContents();

		panel.cancel.DoClick = function(btn)
			panel:Remove();
		end;
	end;

	panel:MakePopup();
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