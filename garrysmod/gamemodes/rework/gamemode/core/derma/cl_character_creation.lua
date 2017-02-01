--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

local PANEL = {};

function PANEL:Init()
	self:SetPos(200, 0);
	self:SetSize(ScrW() - 200, ScrH());
	self:SetTitle("CREATE CHARACTER");

	self.btnClose:SafeRemove();

	self.NameEntry = vgui.Create("DTextEntry", self);
	self.NameEntry:SetPos(8, 100);
	self.NameEntry:SetSize(400, 32);
	self.NameEntry:SetText("");
	self.NameEntry.OnEnter = function(entry)
		chat.AddText(Color("white"), "Creating character named: "..entry:GetValue());

		self.menu:Remove();

		netstream.Start("rw_debug_createchar", entry:GetValue());
	end;
end;

function PANEL:Close(callback)
	self:SetVisible(false);
	self:Remove();

	if (callback) then
		callback();
	end;
end;

function PANEL:AddSidebarItems(sidebar, panel)
	panel:AddButton("General Settings", function (btn) end);
	panel:AddButton("Model", function (btn) end);
	panel:AddButton("Faction", function (btn) end);
	panel:AddButton("Attributes", function (btn) end);

	hook.Run("AddCharacterCreationMenuItems", self, panel, sidebar);
end;

function PANEL:Paint(w, h)
	draw.RoundedBox(0, 0, 0, w, h, Color(30, 30, 30));
	draw.SimpleText("CREATE CHARACTER", "rw_menuitem_large", 24, 42);
	draw.SimpleText("Type in character's name and hit enter to continue. Further options coming in future updates.", "tooltip_small", 10, 82);
end;

vgui.Register("rwCharacterCreation", PANEL, "rwFrame");