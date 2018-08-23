ITEM.name = "Test Item"
ITEM.description = "An item that has a single purpose: system testing. Great, yeah."
ITEM.model = "models/props_junk/metal_paintcan001a.mdl"

function ITEM:on_use(player)
  print("player used item!")
end
