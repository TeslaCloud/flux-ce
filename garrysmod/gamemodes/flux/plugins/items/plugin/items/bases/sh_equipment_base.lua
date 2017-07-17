--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

-- Alternatively, you can use item.CreateBase("CItemEquippable")
class "CItemEquippable" extends "CItem"

CItemEquippable.Name = "Equipment Base"
CItemEquippable.Description = "An item that can be equipped."
CItemEquippable.m_IsEquipped = false

function CItemEquippable:IsEquipped()
	return self.m_IsEquipped
end

function CItemEquippable:OnEquipped(player) end
function CItemEquippable:OnUnEquipped(player) end
function CItemEquippable:PostEquipped(player) end
function CItemEquippable:PostUnEquipped(player) end

function CItemEquippable:Equip(player, bShouldEquip)
	if (bShouldEquip) then
		if (self:OnEquipped(player) != false) then
			self.m_IsEquipped = true
			self:PostEquipped(player)
		end
	else
		if (self:OnUnEquipped(player) != false) then
			self.m_IsEquipped = false
			self:PostUnEquipped(player)
		end
	end
end

ItemEquippable = CItemEquippable