--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

local PANEL = {};
PANEL.CharData = {};

function PANEL:Init()
	self:SetPos(200, 0);
	self:SetSize(ScrW() - 200, ScrH());
	self:SetTitle("CREATE A CHARACTER");

	self.btnClose:SafeRemove();

	self.finishButton = vgui.Create("rwButton", self);
	self.finishButton:SetTitle("FINISH");
	self.finishButton:SetPos(self:GetWide() - 250, self:GetTall() - 120);
	self.finishButton:SetDrawBackground(false);
	self.finishButton:SetFont(theme.GetFont("Text_Large"));
	self.finishButton:SizeToContents();

	self.finishButton.DoClick = function(btn)
		print("click");
		netstream.Start("CreateCharacter", self.CharData);
	end;

	self.finishButton:MoveToFront();

	self:OpenPanel("CharCreation_General");
end;

function PANEL:Close(callback)
	self:SetVisible(false);
	self:Remove();

	if (callback) then
		callback();
	end;
end;

function PANEL:CollectData(newData)
	table.Merge(self.CharData, newData);

	PrintTable(self.CharData);
end;

function PANEL:OpenPanel(id)
	if (IsValid(self.panel)) then
		if (self.panel.OnClose) then
			self.panel:OnClose(self);
		end;

		self.panel:SafeRemove();
	end;

	self.panel = theme.CreatePanel(id, self);
	self.panel:SetSize(self:GetWide() - 200, self:GetTall() - 90);
	self.panel:SetPos(0, 90);

	if (self.panel.OnOpen) then
		self.panel:OnOpen(self);
	end;
end;

function PANEL:AddSidebarItems(sidebar, panel)
	local button = panel:AddButton("General Settings", function(btn)
		self:OpenPanel("CharCreation_General");
	end);

	button:SetActive(true);
	panel.prevButton = button;

	panel:AddButton("Faction", function (btn) 
		self:OpenPanel("CharCreation_Faction");
	end);

	panel:AddButton("Model", function (btn)
		self:OpenPanel("CharCreation_Model");
	end);

	hook.Run("AddCharacterCreationMenuItems", self, panel, sidebar);
end;

function PANEL:Paint(w, h)
	draw.RoundedBox(0, 0, 0, w, h, Color(30, 30, 30));
	draw.SimpleText("CREATE A CHARACTER", theme.GetFont("Text_Large"), 24, 42);
end;

vgui.Register("rwCharacterCreation", PANEL, "rwFrame");