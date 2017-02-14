--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

PLUGIN:SetName("Weapon Selector")
PLUGIN:SetAuthor("Mr. Meow")
PLUGIN:SetDescription("Adds custom weapon selector for use with Rework.")

if (SERVER) then
	concommand.Add("selectweapon", function(player, command, arguments)
		local weapon = player:GetWeapons()[tonumber(arguments[1]) or 1]

		if (IsValid(weapon)) then
			player:SelectWeapon(weapon:GetClass())
		end
	end)

	return
end

PLUGIN.WeaponIndex = 1
PLUGIN.IsOpen = false
PLUGIN.OpenTime = 0
PLUGIN.CurAlpha = 255
PLUGIN.Display = {}
PLUGIN.IndexOffset = nil

local function relativeClamp(n, min, max)
	if (n > max) then
		return relativeClamp(n - max, min, max)
	elseif (n < min) then
		return relativeClamp(max - n, min, max)
	end

	return n
end

local function safeIndex(tab, idx)
	return tab[relativeClamp(idx, 1, #tab)]
end

function PLUGIN:HUDShouldDraw(element)
	if (element == "CHudWeaponSelection") then
		return false
	end
end

function PLUGIN:HUDPaint()
	if (self.IsOpen) then
		if (self.IndexOffset and self.IndexOffset != 0) then
			local dir = (self.IndexOffset == math.abs(self.IndexOffset)) -- true = down, false = up
			local frameTime = FrameTime() * 24
			local targets = {}

			if (!self.Display[1].target) then
				local idx = self.WeaponIndex - ((dir and self.IndexOffset - 1) or self.IndexOffset + 1)
				targets = self:MakeDisplay(idx, true)
			end

			for k, v in ipairs(self.Display) do
				if (!v.target) then
					local next = safeIndex(targets, (dir and k - 1) or k + 1)

					if (dir and k == 1) then
						v.y = targets[5].y + 50
						v.scale = v.scale / 2
					elseif (!dir and k == 5) then
						v.y = targets[1].y - 50
						v.scale = v.scale / 2
					end

					v.target = next.y
					v.scaleTarget = next.scale
					v.weapon = next.weapon
				end

				if (math.abs(v.y - v.target) < 0.25) then
					self.IndexOffset = (dir and self.IndexOffset - 1) or self.IndexOffset + 1
					self:MakeDisplay(self.WeaponIndex - self.IndexOffset)

					break;
				end

				self.Display[k].y = Lerp(frameTime, v.y, v.target)
				self.Display[k].scale = Lerp(frameTime, v.scale, v.scaleTarget)
			end
		end

		local x, y = ScrW() - 306, ScrH() / 2 - 84, 200
		local w, h = 200, 186

		render.SetScissorRect(x, y, x + w, y + h, true)

		draw.RoundedBox(0, x, y, w, h, Color(40, 40, 40, 100 * (self.CurAlpha / 255)))

		for k, v in ipairs(self.Display) do
			rw.core:DrawScaledText(v.weapon:GetPrintName():upper(), theme.GetFont("Text_NormalLarge"), v.x, v.y, v.scale, Color(255, 255, 255, self.CurAlpha * v.scale))
		end

		render.SetScissorRect(0, 0, 0, 0, false)
	end
end

function PLUGIN:Think()
	if (self.IsOpen) then
		if (CurTime() - self.OpenTime > 5) then
			self.CurAlpha = math.Clamp(self.CurAlpha - 2, 0, 255)

			if (self.CurAlpha == 0) then
				self.IsOpen = false
			end
		else
			self.CurAlpha = Lerp(FrameTime() * 16, self.CurAlpha, 255)
		end
	end
end

function PLUGIN:MakeDisplay(index, tab)
	local clientWeapons = rw.client:GetWeapons()
	local count = table.Count(clientWeapons)
	local offsetY = 32
	local result = {}

	for i = -2, 2 do
		local scale = 1 - math.abs(i * 0.25)

		table.insert(result, {
			weapon = safeIndex(clientWeapons, index + i),
			scale = scale,
			x = ScrW() - 300,
			y = ScrH() / 2 - 90 + offsetY - 36 * scale / 2
		})

		offsetY = offsetY + 32
	end

	if (tab) then
		return result
	else
		self.Display = result
	end
end

function PLUGIN:OnWeaponIndexChange(oldIndex, index)
	self.IsOpen = true
	self.OpenTime = CurTime()

	if (#self.Display == 0) then
		self:MakeDisplay(index)
	else
		self.IndexOffset = index - oldIndex
	end
end

function PLUGIN:OnWeaponSelected(index)
	self.IsOpen = false
	self.CurAlpha = 0
	self.Display = {}
end

function PLUGIN:PlayerBindPress(player, bind, bIsPressed)
	local weapon = player:GetActiveWeapon()

	if (!player:InVehicle() and (!IsValid(weapon) or weapon:GetClass() != "weapon_physgun")) then
		local weaponCount = table.Count(player:GetWeapons())
		local oldIndex = self.WeaponIndex
		bind = bind:lower()

		if (bind:find("invprev") and bIsPressed) then
			self.WeaponIndex = relativeClamp(self.WeaponIndex - 1, 1, weaponCount)

			plugin.Call("OnWeaponIndexChange", oldIndex, self.WeaponIndex)

			return true
		elseif (bind:find("invnext") and bIsPressed) then
			self.WeaponIndex = relativeClamp(self.WeaponIndex + 1, 1, weaponCount)

			plugin.Call("OnWeaponIndexChange", oldIndex, self.WeaponIndex)

			return true
		elseif (bind:find("slot") and bIsPressed) then
			local index = tonumber(bind:sub(5, bind:len())) or 1

			index = relativeClamp(index, 1, weaponCount)

			self.WeaponIndex = index

			plugin.Call("OnWeaponIndexChange", oldIndex, index)

			return true
		elseif (bind:find("attack") and self.IsOpen and bIsPressed) then
			RunConsoleCommand("selectweapon", self.WeaponIndex)

			plugin.Call("OnWeaponSelected", self.WeaponIndex)

			return true
		end
	end
end