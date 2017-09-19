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
CItemWeapon.WeaponCategory = "secondary"

function CItemWeapon:OnEquipped(player) end
function CItemWeapon:OnUnEquipped(player) end

function CItemWeapon:PostEquipped(player) 
	player:Notify("Equipped")
end

function CItemWeapon:PostUnEquipped(player)
	player:Notify("Unequipped")
end

ItemWeapon = CItemWeapon