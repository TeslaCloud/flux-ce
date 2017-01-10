--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

local logoMat = Material("rework/rw_icon.png");

local PANEL = {};

function PANEL:Init()
	self:SetPos(0, 0);
	self:SetSize(ScrW(), ScrH());

	local newText = L("#MainMenu_New");
	textW, textH = util.GetTextSize(newText, menuFont);

	self.new = vgui.Create("reButton", self);
	self.new:SetSize(textW * 1.1, textH * 1.1);
	self.new:SetPos(100, 170);
	self.new:SetText(newText);
	self.new:SetDrawBackground(false);
	self.new:SetFont(rw.fonts:GetSize("menu_thin_large", 24));
	self.new:SizeToContents();

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

	local loadText = L("#MainMenu_Load");
	textW, textH = util.GetTextSize(loadText, "menu_thin_large");

	self.load = vgui.Create("reButton", self);
	self.load:SetSize(textW * 1.1, textH * 1.1);
	self.load:SetPos(100, 200);
	self.load:SetText(loadText);
	self.load:SetDrawBackground(false);
	self.load:SetFont(rw.fonts:GetSize("menu_thin_large", 24));
	self.load:SizeToContents();

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

	if (rw.client:GetActiveCharacter()) then
		local cancelText = L("#MainMenu_Cancel");
		textW, textH = util.GetTextSize(cancelText, menuFont);
		
		self.cancel = vgui.Create("reButton", self);
		self.cancel:SetSize(textW * 1.1, textH * 1.1);
		self.cancel:SetPos(100, 230);
		self.cancel:SetText(cancelText);
		self.cancel:SetDrawBackground(false);
		self.cancel:SetFont(rw.fonts:GetSize("menu_thin_large", 24));
		self.cancel:SizeToContents();

		self.cancel.DoClick = function(btn)
			self:Remove();
		end;
	end;

	self:MakePopup();

	theme.Hook("CreateMainMenu", self);
end;

function PANEL:Paint(w, h)
	if (!theme.Hook("DrawMainMenu", self)) then
		surface.SetDrawColor(Color(0, 0, 0));
		surface.DrawRect(0, 0, w, h);

		surface.SetDrawColor(Color("white"));
		surface.SetMaterial(logoMat);
		surface.DrawTexturedRect(75, 30, 200, 204);
	end;
end;

function PANEL:Think()
	theme.Hook("MainMenuThink", self);
end;

vgui.Register("reMainMenu", PANEL, "EditablePanel");

concommand.Add("rwFactoryTest", function()
	local frame = vgui.Create("reFrame");
	frame:SetSize(600, 400);
	frame:SetPos(100, 100);

	local btn = vgui.Create("reButton", frame);
	btn:SetPos(1, 24);
	btn:SetText("Some Button");
	btn.DoClick = function(button)
		print("button click");
	end;
	local font = rw.fonts:GetSize("rw_frame_title", 16)
	btn:SetFont(font);
	btn:SetIcon("fa-cog")
	btn:SizeToContents();

	frame:MakePopup();
end);