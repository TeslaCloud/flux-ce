--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

local PANEL = {}

local colorWhite = Color(255, 255, 255, 255)
local colorBlack = Color(0, 0, 0, 100)

local menuFont = "menu_thin"

function PANEL:Init()
	local scrW, scrH = ScrW(), ScrH()

	self:SetSize(scrW * 0.6, scrH * 0.6)

	self:Rebuild()

	local sbHooks = {}

	function sbHooks:PlayerInitialSpawn(player)
		self:Rebuild()
	end

	function sbHooks:PlayerDisconnected(player)
		self:Rebuild()
	end

	plugin.AddHooks("ScoreboardHooks", sbHooks)
end

function PANEL:Rebuild()
	local w, h = self:GetWide(), self:GetTall()

	if (self.playerList) then
		self.playerList:Remove()
		self.playerList = nil
	end

	self.playerList = vgui.Create("DScrollPanel", self)

	self.playerList:SetPos(0, 0)
	self.playerList:SetSize(w, h)

	local players = player.GetAll()

	local y = self.playerList:GetTall() * 0.01

	self.players = {}

	for k, v in pairs(players) do
		local playerPanel = vgui.Create("rwScoreboardPlayer", self.playerList)

		playerPanel:SetSize(w * 0.98, h * 0.1)
		playerPanel:SetPos(w * 0.005, y)
		playerPanel:SetPlayer(v)

		self.players[#self.players + 1] = playerPanel

		y = y + playerPanel:GetTall() * 1.1
	end
end

function PANEL:OnRemove()
	plugin.RemoveHooks("ScoreboardHooks")
end

-- Since the model panels don't fade properly.
function PANEL:OnFade()
	for k, v in ipairs(self.players) do
		v.mPanel:Remove()
		v.mPanel = nil
	end
end

function PANEL:Paint(w, h)
	surface.SetDrawColor(rw.settings:GetColor("MenuBackColor"))
	surface.DrawRect(0, 0, w, h)
end

derma.DefineControl("rwScoreboard", "", PANEL, "DPanel")

local PANEL = {}

function PANEL:Init()
end

function PANEL:SetPlayer(player)
	local w, h = self:GetWide(), self:GetTall()
	local aSize = h * 0.9

	self.player = player

	self.avatar = vgui.Create("AvatarImage", self)
	self.avatar:SetPos(h * 0.05, h * 0.05)
	self.avatar:SetSize(aSize, aSize)
	self.avatar:SetPlayer(player, 64)
	self.avatar:SetCursor("hand")

	local steam64 = player:SteamID64()

	function self.avatar:OnMousePressed(nKey)
		if (nKey == MOUSE_LEFT) then
			gui.OpenURL("http://steamcommunity.com/profiles/"..steam64)
		end
	end

	self.mBack = vgui.Create("EditablePanel", self)
	self.mBack:SetPos(self.avatar.x + self.avatar:GetWide() + w * 0.01, self.avatar.y)
	self.mBack:SetSize(aSize, aSize)

	function self.mBack:Paint(w, h)
		draw.RoundedBox(4, 0, 0, w, h, ColorAlpha(rw.settings:GetColor("TextColor"), 50))
	end

	self.mPanel = vgui.Create("DModelPanel", self)
	self.mPanel:SetPos(self.avatar.x + self.avatar:GetWide() + w * 0.01, self.avatar.y)
	self.mPanel:SetSize(aSize, aSize)
	self.mPanel:SetModel(player:GetModel())
	self.mPanel:SetCamPos(Vector(15, 3, 65))
	self.mPanel:SetLookAt(Vector(0, 0, 65))

	function self.mPanel:LayoutEntity(ent)
		self:RunAnimation()
	end

	function self.mPanel:LookAtBone(bone)
		local ent = self:GetEntity()

		if (IsValid(ent)) then
			local bone = ent:LookupBone(bone)

			if (bone) then
				local position = ent:GetBonePosition(bone)

				if (position) then
					local oldPos = self:GetCamPos()

					oldPos.z = position.z

					self:SetCamPos(oldPos)
					self:SetLookAt(position)
				end
			end
		end
	end

	function self.mPanel:SetAnimation(anim)
		if (!anim) then return; end

		local ent = self:GetEntity()

		if (IsValid(ent)) then
			-- We do this check so our client doesn't crash if we supply an anim the model doesn't have.
			if (isnumber(anim) and anim >= 0) then
				ent:SetSequence(anim)
			end
		end
	end

	self.mPanel:LookAtBone("ValveBiped.Bip01_Head1")
	self.mPanel:SetAnimation(ACT_IDLE)

	self.name = player:Name()
end

function PANEL:Paint(w, h)
	surface.SetDrawColor(colorBlack)
	surface.DrawRect(0, 0, w, h)

	if (self.name and self.mPanel) then
		draw.SimpleText(self.name, menuFont, self.mPanel.x + self.mPanel:GetWide() + w * 0.01, h * 0.5, rw.settings:GetColor("TextColor"), nil, TEXT_ALIGN_CENTER)
	end
end

derma.DefineControl("rwScoreboardPlayer", "", PANEL, "DPanel");