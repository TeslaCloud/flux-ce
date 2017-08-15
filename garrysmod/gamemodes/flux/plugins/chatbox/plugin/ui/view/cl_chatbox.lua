--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local PANEL = {}
PANEL.history = {}
PANEL.lastPos = 0

function PANEL:Init()
	local w, h = self:GetWide(), self:GetTall()

	self.scrollPanel = vgui.Create("DScrollPanel", self)
	self.scrollPanel:SetPos(0, 0)
	self.scrollPanel:SetSize(w, h)
	self.scrollPanel.Paint = function() return true end


end

function PANEL:CreateMessage(messageData)
	local panel = vgui.Create("flChatMessage", self)



	return panel
end

function PANEL:AddMessage(panel)
	if (#self.history >= config.Get("chatbox_max_messages")) then
		self.history[1]:Eject()
	end

	local idx = table.insert(self.history, panel)

	panel:SetPos(0, self.lastPos)
	panel.messageIndex = idx

	self:AddItem(panel)

	self.lastPos = self.lastPos + config.Get("chatbox_message_margin") + panel:GetTall()
end

function PANEL:RemoveMessage(idx)
	table.remove(self.history, idx)
end

function PANEL:Rebuild()
	self.lastPos = 0

	-- Reversed ipairs anyone?????
	for i = #self.history, 1, -1 do
		local v = self.history[i]

		v:SetPos(0, self.lastPos)

		self.lastPos = self.lastPos + config.Get("chatbox_message_margin") + v:GetTall()
	end
end

function PANEL:Paint(w, h)

end

vgui.Register("flChatPanel", PANEL, "flBasePanel")