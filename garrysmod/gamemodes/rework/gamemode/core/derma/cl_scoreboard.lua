local PANEL = {};

local colorWhite = Color(255, 255, 255, 255);
local colorBlack = Color(0, 0, 0, 100);

function PANEL:Init()
	local scrW, scrH = ScrW(), ScrH();

	self:SetSize(scrW * 0.6, scrH * 0.6);

	self:Rebuild();
end;

function PANEL:Rebuild()
	local w, h = self:GetWide(), self:GetTall();

	if (self.playerList) then
		self.playerList:Remove();
		self.playerList = nil;
	end;

	self.playerList = vgui.Create("DScrollPanel", self);

	self.playerList:SetPos(0, 0);
	self.playerList:SetSize(w, h);

	local players = player.GetAll();

	local y = self.playerList:GetTall() * 0.01;

	for k, v in pairs(players) do
		local playerPanel = vgui.Create("rwScoreboardPlayer", self.playerList);

		playerPanel:SetSize(w * 0.98, h * 0.1);
		playerPanel:SetPos(w * 0.005, y);
		playerPanel:SetPlayer(v);

		y = y + playerPanel:GetTall() * 1.1;
	end;
end;

function PANEL:Paint(w, h)
	draw.RoundedBox(0, 0, 0, w, h, rw.settings.GetColor("MenuBackColor"));
end;

derma.DefineControl("rwScoreboard", "", PANEL, "DPanel");

local PANEL = {};

function PANEL:Init()
end;

function PANEL:SetPlayer(player)
	local w, h = self:GetWide(), self:GetTall();
	local aSize = h * 0.9;

	self.avatar = vgui.Create("AvatarImage", self);
	self.avatar:SetPos(h * 0.05, h * 0.05);
	self.avatar:SetSize(aSize, aSize);
	self.avatar:SetPlayer(player, 64);
	self.avatar:SetCursor("hand");

	local steam64 = player:SteamID64();

	function self.avatar:OnMousePressed(nKey)
		if (nKey == MOUSE_LEFT) then
			gui.OpenURL("http://steamcommunity.com/profiles/"..steam64);
		end;
	end;

	self.name = player:Name();
end;

function PANEL:Paint(w, h)
	draw.RoundedBox(0, 0, 0, w, h, colorBlack);

	if (self.name) then
		draw.SimpleText(self.name, "DermaLarge", self.avatar.x + self.avatar:GetWide() * 1.1, h * 0.5, colorWhite, nil, TEXT_ALIGN_CENTER);
	end;
end;

derma.DefineControl("rwScoreboardPlayer", "", PANEL, "DPanel");