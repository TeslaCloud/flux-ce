if !ItemWeapon then
  util.include("sh_weapon_base.lua")
end

-- Alternatively, you can use item.CreateBase("ItemThrown")
class "ItemThrown" extends "ItemWeapon"

ItemThrown.name = "Thrown Base"
ItemThrown.description = "An weapon that can be thrown."
ItemThrown.category = t('item.category.thrown')
ItemThrown.equip_slot = t('weapon.category.thrown')
ItemThrown.weapon_class = "weapon_frag"
ItemThrown.thrown_ammo_class = "Grenade"
ItemThrown:add_button(t('item.option.unload'), {
  icon = "icon16/add.png",
  callback = "OnUnload",
  onShow = function(item_table)
    return false
  end
})

function ItemThrown:PostEquipped(player)
  local weapon = player:Give(self.weapon_class, true)

  if IsValid(weapon) then
    player:SetActiveWeapon(weapon)
    player:SetAmmo(1, self.thrown_ammo_class)
  else
    fl.dev_print("Invalid weapon class: "..self.weapon_class)
  end
end

function ItemThrown:PostUnEquipped(player)
  local weapon = player:GetWeapon(self.weapon_class)

  if IsValid(weapon) then
    player:StripWeapon(self.weapon_class)

    if player:GetAmmoCount(self.thrown_ammo_class) == 0 then
      player:TakeItemByID(self.instance_id)
    end
  else
    fl.dev_print("Invalid weapon class: "..self.weapon_class)
  end
end
