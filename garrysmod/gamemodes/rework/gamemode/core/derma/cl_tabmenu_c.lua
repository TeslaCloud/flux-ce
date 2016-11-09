local PANEL = {};

local menuFont = "menu_thin_large";

local slideOffset = 0.1;
local outlineSize = 0.5;
local fadeDuration = 0.2;

local colorBlack = Color(0, 0, 0, 255);
local colorWhite = Color(255, 255, 255, 255);

function PANEL:Init()
	local scrW, scrH = ScrW(), ScrH();

	self:SetSize(scrW, scrH);
	self:SetPos(0, 0);

	self.menus = {};

	plugin.Call("AdjustTabDockMenus", self.menus);

	for k, v in pairs(self.menus) do
		if (isnumber(k)) then continue; end;

		v.name = k;

		table.insert(self.menus, v);

		self.menus[k] = nil;
	end;

	table.sort(self.menus, function(a, b)
		return L("#TabMenu_"..a.name) < L("#TabMenu_"..b.name);
	end);

	table.insert(self.menus, 1, {
		name = "CloseMenu",
		icon = "fa-times"
	});

	local menuNum = 0;

	local y = self:GetTall() * 0.25;
	local x = self:GetWide() * 0.01;

	for k, v in ipairs(self.menus) do
		v.text = L("#TabMenu_"..v.name);

		local textW, textH = util.GetTextSize(v.text, menuFont);
		local button = vgui.Create("DButton", self);
		local buttonH = textH * 1.1;

		button:SetSize(textW * 1.1 + buttonH * 1.1, buttonH);
		button:SetPos(-button:GetWide(), y);
		button:SetText("");

		function button:Paint(w, h)
			local curTime = CurTime();
			local textColor = rw.settings:GetColor("TextColor");

			if (self:IsHovered() and !self.hovered) then
				self.lerpTime = CurTime();
				self.hovered = true;
			elseif (!self:IsHovered() and self.hovered) then
				self.lerpTime = CurTime();
				self.hovered = false;
			end;

			if (self.lerpTime) then
				local fraction = (curTime - self.lerpTime) / fadeDuration;

				if (self.hovered) then
					self.textAlpha = Lerp(fraction, textColor.a, 170);
				else
					self.textAlpha = Lerp(fraction, 170, textColor.a);
				end;
			end;

			local alpha = self.textAlpha;

			local currentPanel = self:GetParent().menu;

			if (IsValid(currentPanel) and v.menu == util.GetPanelClass(currentPanel)) then
				alpha = 170;
			end;

			rw.fa:Draw(v.icon or "fa-check", buttonH * 0.5, h * 0.5, buttonH * 0.75, ColorAlpha(textColor, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER);

			draw.SimpleTextOutlined(v.text, menuFont, buttonH * 1.1, h * 0.5, ColorAlpha(textColor, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, outlineSize, ColorAlpha(colorBlack, alpha));
		end;

		menuNum = menuNum + 1;
		button:MoveTo(x, y, slideOffset * menuNum);

		if (v.name == "CloseMenu") then
			button.DoClick = function(panel)
				self:CloseMenu();
			end;
		else
			button.DoClick = function(panel)
				if (v.menu) then
					self:OpenChildMenu(v.menu);	
				end;

				if (v.callback) then
					v.callback(self);
				end;
			end;
		end;

		v.button = button;

		y = y + button:GetTall() * 1.2;
	end;

	if (rw.savedTab) then
		self:OpenChildMenu(rw.savedTab);
		rw.savedTab = nil;
	end;
end;

function PANEL:OnMousePressed()
	if (self.menu) then
		self:CloseChildMenu();
	end;
end;

function PANEL:CloseMenu(bForce)
	rw.tabMenu = nil;

	if (self.menu) then
		rw.savedTab = util.GetPanelClass(self.menu);
	end;

	self:Remove();
end;

function PANEL:OpenChildMenu(sMenu)
	local class = nil;

	if (IsValid(self.menu)) then
		class = util.GetPanelClass(self.menu);

		self:CloseChildMenu();
	end;

	if (!class or (class and class != sMenu)) then
		local scrW, scrH = ScrW(), ScrH();

		self.menu = vgui.Create(sMenu, self);

		if (self.menu) then
			self.menu:SetPos(scrW * 0.25, scrH * 0.15);
			self.menu:SetAlpha(0);
			self.menu:AlphaTo(255, fadeDuration);
		end;
	end;
end;

function PANEL:CloseChildMenu(bForce)
	if (IsValid(self.menu)) then
		if (bForce) then
			self.menu:Remove();
		else
			self.menu:AlphaTo(0, fadeDuration, nil, function(animData, panel)
				panel:Remove();
			end);
		end;
	end;
end;

function PANEL:Paint(w, h)
//	surface.SetDrawColor(0, 0, 0, 255);
//	surface.DrawRect(0, 0, w, h);
end;

vgui.Register("rwTabClassic", PANEL, "EditablePanel");

if (rw.tabMenu) then
	rw.tabMenu:Remove();

	rw.tabMenu = rw.theme:OpenMenu("TabMenu", nil, "rwTabMenu");
	rw.tabMenu:MakePopup();
end;