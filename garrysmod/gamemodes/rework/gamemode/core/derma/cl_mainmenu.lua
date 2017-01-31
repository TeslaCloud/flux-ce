--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

local PANEL = {};

local colorWhite = Color(255, 255, 255, 255);
local colorBlack = Color(0, 0, 0, 255);

local logoMat = Material("rework/rework_logo.png");

local menuFont = "menu_thin_large";

local outlineSize = 0.5;
local fadeDuration = 0.2;

function PANEL:Init()
	local scrW, scrH = ScrW(), ScrH();

	self:SetAlpha(0);
	self:SetSize(scrW, scrH);
	self:SetPos(0, 0);

	self:AlphaTo(255, fadeDuration);

	local logoW, logoH = 512, 256;

	self.logoPanel = vgui.Create("EditablePanel", self);
	self.logoPanel:SetSize(logoW, logoH * 0.7);
	self.logoPanel:SetPos(scrW * 0.05, scrH * 0.5 - self.logoPanel:GetTall());

	function self.logoPanel:Paint(w, h)
		surface.SetDrawColor(colorWhite);
		surface.SetMaterial(logoMat);
		surface.DrawTexturedRect(0, 0, w, h);
	end;

	local x, y = scrW * 0.05, scrH * 0.5;

	local newText = L("#MainMenu_New");
	
	textW, textH = util.GetTextSize(newText, menuFont);

	self.new = vgui.Create("rwMainButton", self);
	self.new:SetSize(textW * 1.1, textH * 1.1);
	self.new:SetPos(x, y);
	self.new:SetText("");
	self.new.text = newText;

	self.new.DoClick = function(btn)
		self.menu = vgui.Create("DFrame", self);
		self.menu:SetPos(ScrW() / 2 - 300, ScrH() / 4);
		self.menu:SetSize(600, 600);
		self.menu:SetTitle("CREATE CHARACTER");
		self.menu:MakePopup();

		self.NameEntry = vgui.Create("DTextEntry", self.menu);
		self.NameEntry:SetPos(8, 100);
		self.NameEntry:SetSize(400, 32);
		self.NameEntry:SetText("HOPE IT'S NOT 'TEST'");
		self.NameEntry.OnEnter = function(entry)
			chat.AddText(Color("white"), "Creating character named: "..entry:GetValue());

			self.menu:Remove();

			netstream.Start("rw_debug_createchar", entry:GetValue());
		end;
	end;

	y = y + textH * 1.2;

	local loadText = L("#MainMenu_Load");

	textW, textH = util.GetTextSize(loadText, menuFont);

	self.load = vgui.Create("rwMainButton", self);
	self.load:SetSize(textW * 1.1, textH * 1.1);
	self.load:SetPos(x, y);
	self.load:SetText("");
	self.load.text = loadText;
	self.load.DoClick = function(btn)
		self.menu = vgui.Create("DFrame", self);
		self.menu:SetPos(ScrW() / 2 - 300, ScrH() / 4);
		self.menu:SetSize(600, 600);
		self.menu:SetTitle("LOAD CHARACTER");

		self.menu.Paint = function(lp, w, h)
			draw.RoundedBox(0, 0, 0, w, h, Color(40, 40, 40));
			draw.SimpleText("Which one to load", "DermaLarge", 0, 24);

			if (#rw.client:GetAllCharacters() <= 0) then
				draw.SimpleText("wow you have none", "DermaLarge", 0, 24);
			end
		end;

		self.menu:MakePopup();

		self.menu.buttons = {};

		local offY = 0;

		for k, v in ipairs(rw.client:GetAllCharacters()) do
			self.menu.buttons[k] = vgui.Create("DButton", self.menu);
			self.menu.buttons[k]:SetPos(8, 100 + offY);
			self.menu.buttons[k]:SetSize(128, 24);
			self.menu.buttons[k]:SetText(v.name);
			self.menu.buttons[k].DoClick = function()
				netstream.Start("PlayerSelectCharacter", v.uniqueID);
				
				self:Remove();
			end;

			offY = offY + 28
		end;
	end;

	y = y + textH * 1.2;

	local settText = L("#MainMenu_Settings");

	textW, textH = util.GetTextSize(settText, menuFont);

	self.sett = vgui.Create("rwMainButton", self);
	self.sett:SetSize(textW * 1.1, textH * 1.1);
	self.sett:SetPos(x, y);
	self.sett:SetText("");
	self.sett.text = settText;

	self.sett.DoClick = function(btn)
		self:OpenChildMenu("rwSettings");
	end;

	y = y + textH * 1.2;

	local discText = L("#MainMenu_Disconnect");
	
	textW, textH = util.GetTextSize(discText, menuFont);

	self.disc = vgui.Create("rwMainButton", self);
	self.disc:SetSize(textW * 1.1, textH * 1.1);
	self.disc:SetPos(x, y);
	self.disc:SetText("");
	self.disc.text = discText;

	self.disc.DoClick = function(btn)
		RunConsoleCommand("disconnect");
	end;

	y = y + textH * 1.2;

	if (rw.client:GetCharacter()) then
		local CancelText = L("#MainMenu_Cancel");
		textW, textH = util.GetTextSize(CancelText, menuFont);

		self.cancel = vgui.Create("rwMainButton", self);
		self.cancel:SetSize(textW * 1.1, textH * 1.1);
		self.cancel:SetPos(x, y);
		self.cancel:SetText("");
		self.cancel.text = CancelText;

		self.cancel.DoClick = function(btn)
			self:CloseMenu();
		end;
	end;
end;

function PANEL:CloseMenu(bForce)
	if (bForce) then
		self:Remove();

		rw.IntroPanel = nil;
	else
		self:AlphaTo(0, fadeDuration, nil, function(animData, panel)
			panel:CloseMenu(true);
		end);
	end;
end;

function PANEL:OpenChildMenu(sMenu)
	local class = nil;

	if (self.menu) then
		class = util.GetPanelClass(self.menu);

		self:CloseChildMenu(true);
	end;

	if (!class or (class and class != sMenu)) then
		local scrW, scrH = ScrW(), ScrH();

		self.menu = vgui.Create(sMenu, self);

		if (self.menu) then
			self.menu:SetPos(scrW * 0.325, scrH * 0.2);
		end;
	end;
end;

function PANEL:CloseChildMenu(bForce)
	if (self.menu) then
		self.menu:Remove();
	end;
end;

function PANEL:Paint(w, h)
	draw.RoundedBox(0, 0, 0, w, h, colorBlack);

	if (!rw.client or !rw.client:HasInitialized()) then
		draw.SimpleText("LOADING...", "DermaLarge", 100, 100);
	end;
end;

function PANEL:OnRemove()
	rw.IntroPanel = nil;
end;

function PANEL:Think()
	if (rw.client:HasInitialized()) then
		self.new:SetVisible(true);
		self.load:SetVisible(true);

		if (#rw.client:GetAllCharacters() <= 0) then
			self.load:SetEnabled(false);
		else
			self.load:SetEnabled(true);
		end;
	end;
end;

vgui.Register("rwMainMenu", PANEL, "Panel");

local PANEL = {};

function PANEL:Paint(w, h)
	local curTime = CurTime();
	local textColor = rw.settings:GetColor("TextColor");
	local bDisabled = self:GetDisabled();

	if (!bDisabled) then
		if (self:IsHovered() and !self.hovered) then
			self.lerpTime = CurTime();
			self.hovered = true;
		elseif (!self:IsHovered() and self.hovered) then
			self.lerpTime = CurTime();
			self.hovered = false;
		end;
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

	if (bDisabled) then
		alpha = 140;
	end;

	draw.SimpleTextOutlined(self.text, menuFont, 0, h * 0.5, ColorAlpha(textColor, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, outlineSize, ColorAlpha(colorBlack, alpha));
end;

vgui.Register("rwMainButton", PANEL, "DButton");
--[[
if (rw.IntroPanel) then
	rw.IntroPanel:Remove();

	rw.IntroPanel = vgui.Create("rwMainMenu");
	rw.IntroPanel:MakePopup();
end;
--]]