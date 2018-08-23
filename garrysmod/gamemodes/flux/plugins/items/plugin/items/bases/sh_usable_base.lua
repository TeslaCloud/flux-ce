-- Alternatively, you can use item.CreateBase("ItemUsable")
class "ItemUsable" extends "Item"

ItemUsable.name = "Usable Items Base"
ItemUsable.description = "An item that can be used."

-- Returns:
-- nothing/nil = removes item from the inventory as soon as it's used.
-- false = prevents item from being used at all.
-- true = prevents item from being removed upon use.
function Item:OnUse(player) end
