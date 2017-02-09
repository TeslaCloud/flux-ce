--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

library.New("notification", rw)

local display = {}
local top = 1
local lastReposition = CurTime()

function rw.notification:Add(text, lifetime, textColor, backColor)
	lifetime = lifetime or 8
	text = rw.lang:TranslateText(text)

	display[top] = {text = text, lifetime = lifetime, panel = nil, width = 0, height = 0, isLast = true}

	if (display[top - 1]) then
		display[top - 1].isLast = false
	end

	local panel = vgui.Create("rwNotification")
	panel:SetText(text)
	panel:SetLifetime(lifetime)
	panel:SetTextColor(textColor)
	panel:SetBackgroundColor(backColor)

	local w, h = panel:GetSize()
	panel:SetPos(ScrW() - w - 8, -h)
	panel:MoveTo(ScrW() - w - 8, 8, 0.26)

	display[top].panel = panel
	display[top].width = w
	display[top].height = h

	timer.Simple(lifetime, function()
		display[top] = nil
	end)

	top = top + 1

	self:Reposition(h)
end

function rw.notification:AddPopup(text, lifetime, x, y, textColor, backColor)
	local panel = vgui.Create("rwNotification")
	panel:SetPos(x, y)
	panel:SetText(text)
	panel:SetLifetime(lifetime)
	panel:SetTextColor(textColor)
	panel:SetBackgroundColor(backColor)

	function panel:PostThink()
		self:MoveToFront()
	end
end

function rw.notification:Reposition(offset)
	if (!isnumber(offset)) then return end

	local curTime = CurTime()

	if (lastReposition + 0.3 < curTime) then
		for k, v in ipairs(display) do
			if (v and IsValid(v.panel)) then
				local x, y = v.panel:GetPos()

				v.panel:MoveTo(x, y + offset + 4, 0.26)
			end
		end

		lastReposition = curTime
	else
		timer.Simple(0.3 - (curTime - lastReposition), function()
			self:Reposition()
		end)
	end
end