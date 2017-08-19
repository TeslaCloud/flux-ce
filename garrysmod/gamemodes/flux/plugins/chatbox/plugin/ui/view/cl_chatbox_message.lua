--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local PANEL = {}
PANEL.messageData = {}
PANEL.compiled = {}
PANEL.addTime = 0
PANEL.forceShow = false
PANEL.shouldPaint = false

function PANEL:Init()
	--if (fl.client:HasPermission("chat_mod")) then
	--	self.moderation = vgui.Create("flChatModeration", self)
	--end

	self.addTime = CurTime()
	self.fadeTime = self.addTime + config.Get("chatbox_message_fade_delay")
end

function PANEL:Think()
	self.shouldPaint = false

	if (self.forceShow) then
		self.shouldPaint = true
	elseif (self.fadeTime > CurTime()) then
		self.shouldPaint = true
	end
end

function PANEL:SetMessage(msgInfo)
	self.messageData = msgInfo

	local totalHeight = 0
	local margin = config.Get("chatbox_message_margin")

	for k, v in ipairs(msgInfo) do
		totalHeight = totalHeight + v.height + margin
	end

	self:SetSize(self:GetWide(), totalHeight)
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
	if (self.shouldPaint) then
		local curColor = Color(255, 255, 255)
		local curSize = 16
		local italic = false
		local bold = false
		local curX = 0
		local curY = 0

		for _, line in ipairs(self.messageData) do
			for _, v in ipairs(line.data) do
				if (IsColor(v)) then
					curColor = v
				elseif (isnumber(v)) then
					if (v == CHAT_NONE) then
						italic = false
						bold = false
						curSize = 16
						curColor = Color(255, 255, 255)
					elseif (v == CHAT_IMAGE) then

					end
				end
			end
		end
	end
end

vgui.Register("flChatMessage", PANEL, "flBasePanel")