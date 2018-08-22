if (!CItemUsable) then
  util.Include("sh_usable_base.lua")
end

-- Alternatively, you can use item.CreateBase("CItemAmmo")
class "CItemAmmo" extends "CItemUsable"

CItemAmmo.Name = "Usable Items Base"
CItemAmmo.Description = "An item that can be used."
CItemAmmo.Category = "#Item_Category_Ammo"
CItemAmmo.Model = "models/Items/BoxSRounds.mdl"
CItemAmmo.UseText = "#Item_Option_Load"
CItemAmmo.AmmoClass = "Pistol"
CItemAmmo.AmmoAmount = 20

function CItemAmmo:OnUse(player)
  player:GiveAmmo(self.AmmoAmount, self.AmmoClass)
end

ItemAmmo = CItemAmmo
