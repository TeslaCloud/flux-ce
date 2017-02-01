--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

local logoMat = Material("rework/rw_icon.png");

local PANEL = {};
PANEL.buttons = {};

function PANEL:Init()
	self:SetPos(0, 0);
	self:SetSize(ScrW(), ScrH());

	self:RecreateSidebar(true);

	self:MakePopup();

	theme.Hook("CreateMainMenu", self);
end;

function PANEL:Paint(w, h)
	if (!theme.Hook("DrawMainMenu", self)) then
		surface.SetDrawColor(Color(0, 0, 0));
		surface.DrawRect(0, 0, w, h);
	end;
end;

function PANEL:Think()
	theme.Hook("MainMenuThink", self);
end;

function PANEL:RecreateSidebar(bShouldCreateButtons)
	if (IsValid(self.sidebar)) then
		self.sidebar:SafeRemove();
	end;

	self.sidebar = vgui.Create("rwSidebar", self);
	self.sidebar:SetPos(0, 0);
	self.sidebar:SetSize(200, ScrH());
	self.sidebar:SetMargin(-1);
	self.sidebar.lastPos = 8;

	self.logo = vgui.Create("DImage", self)	-- Add image to Frame
	self.logo:SetSize(110, 100);
	self.logo:SetPos(45, 50);
	self.logo:SetImage("rework/rw_icon.png")

	self.sidebar:AddPanel(self.logo);

	self.sidebar.lastPos = self.sidebar.lastPos + 16;

	if (bShouldCreateButtons) then
		hook.Run("AddMainMenuItems", self, self.sidebar);
	else
		local backButton = vgui.Create("rwButton");
		backButton:SetSize(200, 32);
		backButton:SetMainColor(Color(100, 50, 50));
		backButton:SetAccentColor(Color(75, 75, 75));
		backButton:SetIcon("fa-chevron-left");
		backButton:SetFont(rw.fonts:GetSize("menu_thin_large", 22));
		backButton:SetTitle("BACK");

		backButton.DoClick = function(btn)
			self:RecreateSidebar(true);

			if (self.menu.Close) then
				self.menu:Close();
			else
				self.menu:SafeRemove();
			end;
		end;

		self.sidebar:AddPanel(backButton);
		self.sidebar.lastPos = self.sidebar.lastPos + 9;
	end;
end;

function PANEL:OpenMenu(panel, data)
	if (!IsValid(self.menu)) then
		self.menu = theme.CreatePanel(panel, self);

		if (self.menu.SetData) then
			self.menu:SetData(data);
		end;
	else
		if (self.menu.Close) then
			self.menu:Close(function()
				self:OpenMenu(panel, data);
			end);
		else
			self.menu:SetVisible(false);
			self.menu:Remove();
			self:OpenMenu(panel, data);
		end;
	end;
end;

function PANEL:AddButton(text, callback)
	local button = vgui.Create("rwButton", self);
	button:SetSize(200, 32);
	button:SetText(text);
	button:SetDrawBackground(true);
	button:SetFont(rw.fonts:GetSize("menu_thin_large", 22));
	button:SetTextAutoposition(true);
	button:SetAccentColor(Color(75, 75, 75));

	button.DoClick = (isfunction(callback) and callback) or (isstring(callback) and function(btn)
		self:OpenMenu(callback);
	end) or function() end;

	self.sidebar:AddPanel(button);
end;

vgui.Register("reMainMenu", PANEL, "EditablePanel");