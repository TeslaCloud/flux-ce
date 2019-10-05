ITEM.name = 'Test Item'
ITEM.description = 'An item that has a single purpose: system testing. Great, yeah.'
ITEM.model = 'models/weapons/w_pistol.mdl'
ITEM.width = 2
ITEM.height = 1
ITEM.stackable = true
ITEM.max_stack = 8

function ITEM:get_icon_data()
  return { origin = Vector(0, 200, 0), angles = Angle(0.5, 270, -3), fov = 5 }
end

function ITEM:on_use(player)
  print('player used item!')
end
