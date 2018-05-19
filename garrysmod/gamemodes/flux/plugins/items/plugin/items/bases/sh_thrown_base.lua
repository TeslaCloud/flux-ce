--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

if (!CItemWeapon) then
  util.Include("sh_weapon_base.lua")
end

-- Alternatively, you can use item.CreateBase("CItemThrown")
class "CItemThrown" extends "CItemWeapon"

CItemThrown.Name = "Thrown Base"
CItemThrown.Description = "An weapon that can be thrown."
CItemThrown.Category = "#Item_Category_Thrown"
CItemThrown.EquipSlot = "#Weapon_Category_Thrown"
CItemThrown.WeaponClass = "weapon_frag"
CItemThrown.ThrownAmmoClass = "Grenade"
CItemThrown:AddButton("#Item_Option_Unload", {
  icon = "icon16/add.png",
  callback = "OnUnload",
  onShow = function(itemTable)
    return false
  end
})

function CItemThrown:PostEquipped(player)
  local weapon = player:Give(self.WeaponClass, true)

  if (IsValid(weapon)) then
    player:SetActiveWeapon(weapon)
    player:SetAmmo(1, self.ThrownAmmoClass)
  else
    fl.DevPrint("Invalid weapon class: "..self.WeaponClass)
  end
end

function CItemThrown:PostUnEquipped(player)
  local weapon = player:GetWeapon(self.WeaponClass)

  if (IsValid(weapon)) then
    player:StripWeapon(self.WeaponClass)

    if (player:GetAmmoCount(self.ThrownAmmoClass) == 0) then
      player:TakeItemByID(self.instanceID)
    end
  else
    fl.DevPrint("Invalid weapon class: "..self.WeaponClass)
  end
end

ItemThrow = CItemThrown
