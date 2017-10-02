--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

if (!CItemEquippable) then
	util.Include("sh_equipment_base.lua")
end

-- Alternatively, you can use item.CreateBase("CItemWeapon")
class "CItemWeapon" extends "CItemEquippable"

CItemWeapon.Name = "Weapon Base"
CItemWeapon.Description = "An weapon that can be equipped."
CItemWeapon.Category = "#Item_Category_Weapon"
CItemWeapon.WeaponClass = "weapon_pistol"
CItemWeapon.WeaponCategory = "#Weapon_Category_Secondary"
CItemWeapon:AddButton("#Item_Option_Unload", {
	icon = "icon16/add.png",
	callback = "OnUnload",
	onShow = function(itemTable)
		local ammo = itemTable:GetData("ammo", {0, 0})
		local weapon = fl.client:GetWeapon(itemTable.WeaponClass)

		if ((ammo[1] > 0 or ammo[2] > 0 or IsValid(weapon) and (weapon:Clip1() != 0 or weapon:Clip2() != 0)) 
			and !IsValid(itemTable.Entity) and itemTable:IsEquipped()) then
			return true
		end
	end
})

function CItemWeapon:OnEquipped(player)
	local playerInv = player:GetInventory()

	for slot, ids in ipairs(playerInv) do
		for k, v in ipairs(ids) do
			local itemTable = item.FindInstanceByID(v)

			if (itemTable.ClassName == "CItemWeapon" and itemTable.WeaponCategory == self.WeaponCategory and itemTable:IsEquipped() and itemTable.instanceID != self.instanceID) then
				return false
			end
		end
	end
end

function CItemWeapon:OnUnEquipped(player) end

function CItemWeapon:PostEquipped(player)
	local weapon = player:Give(self.WeaponClass, true)

	if (IsValid(weapon)) then
		local ammo = self:GetData("ammo", {0, 0})

		player:SetActiveWeapon(weapon)
		weapon:SetClip1(ammo[1])
		weapon:SetClip2(ammo[2])
	else
		fl.DevPrint("Invalid weapon class: "..self.WeaponClass)
	end
end

function CItemWeapon:PostUnEquipped(player)
	local weapon = player:GetWeapon(self.WeaponClass)

	if (IsValid(weapon)) then
		local ammo = {weapon:Clip1(), weapon:Clip2()}

		player:StripWeapon(self.WeaponClass)
		self:SetData("ammo", ammo)
	else
		fl.DevPrint("Invalid weapon class: "..self.WeaponClass)
	end
end

function CItemWeapon:OnUnload(player)
	local weapon = player:GetWeapon(self.WeaponClass)
	local clip1, clip2 = weapon:Clip1(), weapon:Clip2()

	weapon:SetClip1(0)
	weapon:SetClip2(0)
	player:GiveAmmo(clip1, weapon:GetPrimaryAmmoType())
	player:GiveAmmo(clip2, weapon:GetSecondaryAmmoType())
	self:SetData("ammo", {0, 0})
end

function CItemWeapon:OnSave(player)
	local weapon = player:GetWeapon(self.WeaponClass)

	if (IsValid(weapon)) then
		local ammo = {weapon:Clip1(), weapon:Clip2()}

		self:SetData("ammo", ammo)
	else
		fl.DevPrint("Invalid weapon class: "..self.WeaponClass)
	end
end

ItemWeapon = CItemWeapon