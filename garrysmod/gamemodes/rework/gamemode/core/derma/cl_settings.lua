local PANEL = {};

local colorWhite = Color(255, 255, 255, 255);
local colorBlack = Color(0, 0, 0, 100);

local outlineSize = 0.5;
local expandDuration = 0.15;

function PANEL:Init()
	local scrW, scrH = ScrW(), ScrH();

	self:SetSize(scrW * 0.6, scrH * 0.6);

	self.elementCallbacks = {};

	plugin.Call("AdjustSettingCallbacks", self.elementCallbacks);

	self.categoryList = vgui.Create("DScrollPanel", self);
	self.categoryList:SetSize(self:GetWide() * 0.2, self:GetTall());
	self.categoryList:SetPos(0, self:GetTall() * 0.5 - self.categoryList:GetTall() * 0.5);
	self.categoryList.Paint = function(panel, w, h)
		draw.RoundedBox(0, 0, 0, w, h, rw.settings.GetColor("MenuBackColor"));
	end;

	self.settingList = vgui.Create("DScrollPanel", self);
	self.settingList:SetSize(self:GetWide() - self.categoryList:GetWide() * 1.05, self:GetTall());
	self.settingList:SetPos(
		self.categoryList.x + self.categoryList:GetWide() * 1.05,
		self:GetTall() * 0.5 - self.settingList:GetTall() * 0.5
	);

	self.settingList.Paint = function(panel, w, h)
		draw.RoundedBox(0, 0, 0, w, h, rw.settings.GetColor("MenuBackColor"));
	end;

	self:BuildCategoryList();
end;

function PANEL:BuildList()
	local setList = self.settingList;
	local x = setList:GetWide() * 0.01;
	local y = x;
	local w, h = setList:GetWide() * 0.98, setList:GetTall() * 0.09;
	local settings = rw.settings.GetCategorySettings(self.activeCategory);

	setList:Clear();

	table.sort(settings, function(a, b)
		return L(a.id) < L(b.id);
	end);

	for k, v in ipairs(settings) do
		local elementCallback = self.elementCallbacks[v.type];

		if ((!v.callback or !v.callback()) and isfunction(elementCallback)) then
			local setting = vgui.Create("EditablePanel", setList);

			setting:SetPos(x, y);
			setting:SetSize(w, h);

			function setting:Paint(w, h)
				draw.RoundedBox(0, 0, 0, w, h, colorBlack);
			end;

			setting.label = vgui.Create("DLabel", setting);
			setting.label:SetFont("DermaLarge");
			setting.label:SetText("#Settings_"..v.id);
			setting.label:SetTextColor(colorWhite);
			setting.label:SizeToContents();
			setting.label:SetPos(setting:GetWide() * 0.01, setting:GetTall() * 0.5 - setting.label:GetTall() * 0.5);

			setting.element = vgui.Create(v.type, setting);

			elementCallback(setting.element, setting, v);

		//	setting.element:SetConVar("RW_"..v.id);

			y = y + setting:GetTall() + setList:GetWide() * 0.01;
		end;
	end;
end;

function PANEL:BuildCategoryList()
	local catList = self.categoryList;
	local x = catList:GetWide() * 0.01
	local y = x;
	local w, h = catList:GetWide() * 0.98, catList:GetTall() * 0.09;
	local categories = rw.settings.GetIndexedCategories(function(a, b)
		return L(a.id) < L(b.id);
	end);

	for k, v in ipairs(categories) do
		local sum = 0;

		for k, v in pairs(v.settings) do
			if (!v.callback or !v.callback()) then
				sum = sum + 1;
			end;
		end;

		-- If there are no available settings, skip the category.
		if (sum == 0) then
			continue;
		end;

		local button = vgui.Create("DButton", catList);

		button:SetPos(x, y);
		button:SetSize(w, h);
		button.text = "#Settings_"..v.id;
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

				if (self.lerpTime) then
					local fraction = (curTime - self.lerpTime) / expandDuration;

					if (self.hovered) then
						self.textAlpha = Lerp(fraction, colorWhite.a, 170);
					else
						self.textAlpha = Lerp(fraction, 170, colorWhite.a);
					end;
				end;

				local alpha = self.textAlpha;

				if (self:GetParent():GetParent():GetParent().activeCategory == self.id) then
					alpha = 170;
				end;

				draw.SimpleTextOutlined(self.text, "DermaLarge", w * 0.1, h * 0.5, ColorAlpha(colorWhite, alpha), TEXT_ALIGN_LEFT, nil, outlineSize, ColorAlpha(colorBlack, alpha));
			end;
		end;
		
		y = y + h * 1.1;
	end;

	self.activeCategory = categories[1].id;
	self:BuildList();
end;

function PANEL:Paint(w, h)
//	draw.RoundedBox(0, 0, 0, w, h, colorWhite);
end;

derma.DefineControl("rwSettings", "", PANEL, "EditablePanel");