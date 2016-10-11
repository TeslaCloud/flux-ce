--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

-- todo finish the panel lol

local PANEL = {};

function PANEL:Init()
	self:SetSize(ScrW(), ScrH());
	self:SetPos(0, 0);

	self.ContinueButton = vgui.Create("DButton", self);
	self.ContinueButton:SetPos(ScrW() - 256, ScrH() - 24);
	self.ContinueButton:SetSize(256, 24);
	self.ContinueButton:SetText("Just fucken close this panel ffs");
	self.ContinueButton.DoClick = function(btn)
		self:SetVisible(false);
		self:Remove();
	end;

	self.LoadButton = vgui.Create("DButton", self);
	self.LoadButton:SetPos(ScrW() / 1.25 - 196, 24);
	self.LoadButton:SetSize(196, 24);
	self.LoadButton:SetText("Load Character");
	self.LoadButton:SetVisible(false);
	self.LoadButton.DoClick = function(btn)
		self.LoadPanel = vgui.Create("DFrame", self);
		self.LoadPanel:SetPos(ScrW() / 2 - 300, ScrH() / 4);
		self.LoadPanel:SetSize(600, 600);
		self.LoadPanel:SetTitle("LOAD CHARACTER");

		self.LoadPanel.Paint = function(lp, w, h)
			draw.RoundedBox(0, 0, 0, w, h, Color(40, 40, 40));
			draw.SimpleText("Which one to load", "DermaLarge", 0, 24);

			if (#rw.client:GetAllCharacters() <= 0) then
				draw.SimpleText("wow you have none", "DermaLarge", 0, 24);
			end
		end;

		self.LoadPanel:MakePopup();

		self.LoadPanel.buttons = {};
		local offY = 0;

		for k, v in ipairs(rw.client:GetAllCharacters()) do
			self.LoadPanel.buttons[k] = vgui.Create("DButton", self.LoadPanel);
			self.LoadPanel.buttons[k]:SetPos(8, 100 + offY);
			self.LoadPanel.buttons[k]:SetSize(128, 24);
			self.LoadPanel.buttons[k]:SetText(v.name);
			self.LoadPanel.buttons[k].DoClick = function()
				netstream.Start("PlayerSelectCharacter", v.uniqueID);
				self.LoadPanel:SetVisible(false);
			end;

			offY = offY + 28
		end;
	end;

	self.CreateButton = vgui.Create("DButton", self);
	self.CreateButton:SetPos(ScrW() / 4, 24);
	self.CreateButton:SetSize(196, 24);
	self.CreateButton:SetText("Create Character");
	self.CreateButton:SetVisible(false);
	self.CreateButton.DoClick = function(btn)
		self.CreatePanel = vgui.Create("DFrame", self);
		self.CreatePanel:SetPos(ScrW() / 2 - 300, ScrH() / 4);
		self.CreatePanel:SetSize(600, 600);
		self.CreatePanel:SetTitle("CREATE CHARACTER");
		self.CreatePanel:MakePopup();

		self.NameEntry = vgui.Create("DTextEntry", self.CreatePanel)
		self.NameEntry:SetPos(8, 100);
		self.NameEntry:SetSize(400, 32);
		self.NameEntry:SetText("HOPE IT'S NOT 'TEST'");
		self.NameEntry.OnEnter = function(entry)
			chat.AddText(Color("white"), "Creating character named: "..entry:GetValue());

			netstream.Start("rw_debug_createchar", entry:GetValue());
		end
	end;
end;

function PANEL:Paint(w, h)
	draw.RoundedBox(0, 0, 0, w, h, Color(20, 20, 20));

	draw.SimpleText("WOW SUCH UI'S", "DermaLarge", ScrW() / 2 - 92, 500);

	if (!rw.client or !rw.client:HasInitialized()) then
		draw.SimpleText("LOADING...", "DermaLarge", 100, 100);
	end;
end;

function PANEL:Think()
	if (rw.client:HasInitialized()) then
		self.CreateButton:SetVisible(true);
		self.LoadButton:SetVisible(true);

		if (#rw.client:GetAllCharacters() <= 0) then
			self.LoadButton:SetEnabled(false);
		else
			self.LoadButton:SetEnabled(true);
		end;
	end;
end;

vgui.Register("reMainMenu", PANEL, "Panel");