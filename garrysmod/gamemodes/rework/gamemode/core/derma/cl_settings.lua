local PANEL = {};

local colorWhite = Color(255, 255, 255, 255);
local colorBlack = Color(0, 0, 0, 200);

local outlineSize = 0.5;
local expandDuration = 0.15;

local menuFont = "menu_thin";
local menuFontSmall = "menu_thin_small";

function PANEL:Init()
	local scrW, scrH = ScrW(), ScrH();

	self:SetSize(scrW * 0.6, scrH * 0.6);

	self.elementCallbacks = {};

	plugin.Call("AdjustSettingCallbacks", self.elementCallbacks);

	self.categoryList = vgui.Create("DScrollPanel", self);
	self.categoryList:SetSize(self:GetWide() * 0.2, self:GetTall());
	self.categoryList:SetPos(0, self:GetTall() * 0.5 - self.categoryList:GetTall() * 0.5);
	self.categoryList.Paint = function(panel, w, h)
		surface.SetDrawColor(rw.settings:GetColor("MenuBackColor"));
		surface.DrawRect(0, 0, w, h);
	end;

	self.settingList = vgui.Create("DScrollPanel", self);
	self.settingList:SetSize(self:GetWide() - self.categoryList:GetWide() * 1.05, self:GetTall());
	self.settingList:SetPos(
		self.categoryList.x + self.categoryList:GetWide() * 1.05,
		self:GetTall() * 0.5 - self.settingList:GetTall() * 0.5
	);

	self.settingList.Paint = function(panel, w, h)
		surface.SetDrawColor(rw.settings:GetColor("MenuBackColor"));
		surface.DrawRect(0, 0, w, h);
	end;

	self:BuildCategoryList();
end;

function PANEL:BuildList()
	local oldList = self.settingList;

	if (oldList) then
		oldList:AlphaTo(0, expandDuration, nil, nil, function(animData, panel)
			panel:Remove();
		end);
	end;

	self.settingList = vgui.Create("DScrollPanel", self);
	self.settingList:SetSize(self:GetWide() - self.categoryList:GetWide() * 1.05, self:GetTall());
	self.settingList:SetPos(
		self.categoryList.x + self.categoryList:GetWide() * 1.05,
		self:GetTall() * 0.5 - self.settingList:GetTall() * 0.5
	);
	self.settingList.Paint = function(panel, w, h)
		surface.SetDrawColor(rw.settings:GetColor("MenuBackColor"));
		surface.DrawRect(0, 0, w, h);
	end;
	self.settingList:SetAlpha(0);
	self.settingList:AlphaTo(255, expandDuration);

	local setList = self.settingList;
	local x = setList:GetWide() * 0.01;
	local y = x;
	local w, h = setList:GetWide() * 0.98, setList:GetTall() * 0.09;
	local settings = rw.settings:GetCategorySettings(self.activeCategory);

	setList:Clear();

	table.sort(settings, function(a, b)
		return L("#Settings_"..a.id) < L("#Settings_"..b.id);
	end);

	for k, v in ipairs(settings) do
		local elementCallback = self.elementCallbacks[v.type];

		if ((!v.callback or v.callback()) and isfunction(elementCallback)) then
			local setting = vgui.Create("EditablePanel", setList);

			setting:SetPos(x, y);
			setting:SetSize(w, h);

			setting.label = vgui.Create("DLabel", setting);
			setting.label:SetFont(menuFontSmall);
			setting.label:SetText("#Settings_"..v.id);
			setting.label:SetTextColor(rw.settings:GetColor("TextColor"));			
			setting.label:SizeToContents();
			setting.label:SetPos(setting:GetWide() * 0.01, setting:GetTall() * 0.5 - setting.label:GetTall() * 0.5);

			function setting:Paint(w, h)
				surface.SetDrawColor(colorBlack);
				surface.DrawRect(0, 0, w, h);
		
				self.label:SetTextColor(rw.settings:GetColor("TextColor"));
			end;

			setting.element = vgui.Create(v.type, setting);

			elementCallback(setting.element, setting, v);

			y = y + setting:GetTall() + setList:GetWide() * 0.01;
		end;
	end;
end;

function PANEL:BuildCategoryList()
	local catList = self.categoryList;
	local x = 0;
	local y = x;
	local w, h = catList:GetWide(), catList:GetTall() * 0.09;
	local categories = rw.settings:GetIndexedCategories(function(a, b)
		return L("#Settings_"..a.id) < L("#Settings_"..b.id);
	end);
	local saved = rw.settings.lastCat;

	for k, v in ipairs(categories) do
		local sum = 0;

		for k, v in pairs(v.settings) do
			if (!v.callback or v.callback()) then
				sum = sum + 1;
			end;
		end;

		-- If there are no available settings, skip the category.
		if (sum == 0) then
			if (v.id == saved) then
				saved = nil;
			end;

			table.remove(categories, k);
		end;
	end;

	for k, v in ipairs(categories) do
		surface.SetFont(menuFont);

		local name = L("#Settings_"..v.id);
		local textW, textH = surface.GetTextSize(name);

		textW = textW + (w * 0.25);

		if (textW > w) then
			catList:SetSize(textW, catList:GetTall());

			local setList = self.settingList;

			setList:SetSize(self:GetWide() - catList:GetWide() * 1.05, self:GetTall());
			setList:SetPos(
				catList.x + catList:GetWide() * 1.05,
				self:GetTall() * 0.5 - setList:GetTall() * 0.5
			);

			w = catList:GetWide();
		end;

		local button = vgui.Create("DButton", catList);

		button:SetPos(x, y);
		button:SetSize(w, h);
		button.text = name;
		button.textAlpha = colorWhite.a;
		button:SetText("");
		button.id = v.id;

		button.DoClick = function(panel)
			self.activeCategory = panel.id;
			self:BuildList();
		end;

		function button:Paint(w, h)
			if (self.text) then
				local curTime = CurTime();

				if (self:IsHovered() and !self.hovered) then
					self.lerpTime = CurTime();
					self.hovered = true;
				elseif (!self:IsHovered() and self.hovered) then
					self.lerpTime = CurTime();
					self.hovered = false;
				end;

				local textColor = rw.settings:GetColor("TextColor");

				if (self.lerpTime) then
					local fraction = (curTime - self.lerpTime) / expandDuration;

					if (self.hovered) then
						self.textAlpha = Lerp(fraction, textColor.a, 170);
					else
						self.textAlpha = Lerp(fraction, 170, textColor.a);
					end;
				end;

				local alpha = self.textAlpha;

				if (self:GetParent():GetParent():GetParent().activeCategory == self.id) then
					alpha = 170;
				end;

				--Otherwise things like 'y' or 'g' get cut off.
				DisableClipping(true);
					draw.SimpleTextOutlined(self.text, menuFont, w * 0.1, h * 0.5, ColorAlpha(textColor, alpha), TEXT_ALIGN_LEFT, nil, outlineSize, ColorAlpha(colorBlack, alpha));
				DisableClipping(false);
			end;
		end;
		
		y = y + h * 1.1;
	end;

	if (saved) then
		self.activeCategory = saved;
		rw.settings.lastCat = nil;
	else
		self.activeCategory = categories[1].id;
	end;

	self:BuildList();
end;

function PANEL:OnRemove()
	rw.settings.lastCat = self.activeCategory;
end;

function PANEL:Paint(w, h) end;

derma.DefineControl("rwSettings", "", PANEL, "EditablePanel");