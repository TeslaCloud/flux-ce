--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local PANEL = {}
PANEL.messageData = {}
PANEL.compiled = {}
PANEL.addTime = 0

function PANEL:Init()
	--if (fl.client:HasPermission("chat_mod")) then
	--	self.moderation = vgui.Create("flChatModeration", self)
	--end

	self.addTime = CurTime()
end

function PANEL:SetMessage(msgInfo)
	self.messageData = msgInfo

	local compiled = chatbox.Compile(msgInfo, self)

	if (compiled) then
		self.compiled = compiled

		local ncompiled = #compiled

		if (ncompiled > 1) then
			local wide, tall = self:GetWide(), self:GetTall()

			self:SetSize(wide, tall * ncompiled + (config.Get("chatbox_message_margin") * (ncompiled - 1)))
			self:GetParent():Rebuild()
		end
	end
end

-- Those people want us gone :(
function PANEL:Eject()
	if (plugin.Call("ShouldMessageEject", self) != false) then
		local parent = self:GetParent()

		parent:RemoveMessage(self.messageIndex or 1)
		parent:Rebuild()
		self:SafeRemove()
	end
end

function PANEL:Paint(w, h)
	
end

vgui.Register("flChatMessage", PANEL, "flBasePanel")