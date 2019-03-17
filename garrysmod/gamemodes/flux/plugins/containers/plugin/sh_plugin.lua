PLUGIN:set_global('Container')

local stored = Container.stored or {}
Container.stored = stored

do
  function Container:register_prop(model, data)
    if istable(model) then
      for k, v in pairs(model) do
        stored[v:lower()] = data
      end
    else
      stored[model:lower()] = data
    end
  end

  function Container:all()
    return stored
  end
end

util.include('cl_hooks.lua')
util.include('sv_hooks.lua')

Container:register_prop({
  'models/props_junk/cardboard_box001a.mdl',
  'models/props_junk/cardboard_box001b.mdl',
  'models/props_junk/cardboard_box002a.mdl',
  'models/props_junk/cardboard_box002b.mdl'
},
{
  name = 'container.box.title',
  desc = 'container.box.desc',
  w = 4,
  h = 3,
  open_sound = 'physics/cardboard/cardboard_box_impact_soft5.wav',
  close_sound = 'physics/cardboard/cardboard_box_impact_soft7.wav'
})

Container:register_prop('models/props_c17/FurnitureCupboard001a.mdl', {
  name = 'container.cupboard.title',
  desc = 'container.cupboard.desc',
  w = 4,
  h = 3,
  open_sound = 'doors/door1_move.wav',
  close_sound = 'doors/door1_stop.wav'
})

Container:register_prop('models/props_c17/FurnitureDrawer001a.mdl', {
  name = 'container.drawer.title',
  desc = 'container.drawer.desc',
  w = 5,
  h = 4,
  open_sound = 'physics/wood/wood_plank_impact_soft1.wav',
  close_sound = 'physics/wood/wood_box_impact_hard6.wav'
})

Container:register_prop('models/props_c17/FurnitureDrawer002a.mdl', {
  name = 'container.small_drawer.title',
  desc = 'container.small_drawer.desc',
  w = 2,
  h = 1,
  open_sound = 'physics/wood/wood_plank_impact_soft1.wav',
  close_sound = 'physics/wood/wood_box_impact_hard6.wav'
})

Container:register_prop('models/props_c17/FurnitureDrawer003a.mdl', {
  name = 'container.tall_drawer.title',
  desc = 'container.tall_drawer.desc',
  w = 1,
  h = 6,
  open_sound = 'physics/wood/wood_plank_impact_soft1.wav',
  close_sound = 'physics/wood/wood_box_impact_hard6.wav'
})

Container:register_prop('models/props_c17/FurnitureDresser001a.mdl', {
  name = 'container.dresser.title',
  desc = 'container.dresser.desc',
  w = 4,
  h = 6,
  open_sound = 'doors/door1_move.wav',
  close_sound = 'doors/door1_stop.wav'
})

Container:register_prop('models/props_c17/FurnitureFridge001a.mdl', {
  name = 'container.fridge.title',
  desc = 'container.fridge.desc',
  w = 4,
  h = 5,
  open_sound = 'items/ammocrate_open.wav',
  close_sound = 'items/ammocrate_close.wav'
})

Container:register_prop('models/props_c17/Lockers001a.mdl', {
  name = 'container.lockers.title',
  desc = 'container.lockers.desc',
  w = 5,
  h = 4,
  open_sound = 'items/ammocrate_open.wav',
  close_sound = 'items/ammocrate_close.wav'
})

Container:register_prop('models/props_c17/oildrum001.mdl', {
  name = 'container.barrel.title',
  desc = 'container.barrel.desc',
  w = 3,
  h = 5,
  open_sound = 'physics/metal/metal_barrel_impact_soft3.wav',
  close_sound = 'physics/metal/metal_barrel_impact_soft4.wav'
})

Container:register_prop({
  'models/props_combine/breendesk.mdl',
  'models/props_interiors/Furniture_Desk01a.mdl'
}, 
{
  name = 'container.desk.title',
  desc = 'container.desk.desc',
  w = 5,
  h = 3,
  open_sound = 'physics/wood/wood_plank_impact_soft1.wav',
  close_sound = 'physics/wood/wood_box_impact_hard6.wav'
})

Container:register_prop({
  'models/props_junk/cardboard_box003a.mdl',
  'models/props_junk/cardboard_box003b.mdl'
},
{
  name = 'container.medium_box.title',
  desc = 'container.medium_box.desc',
  w = 3,
  h = 2,
  open_sound = 'physics/cardboard/cardboard_box_impact_soft5.wav',
  close_sound = 'physics/cardboard/cardboard_box_impact_soft7.wav'
})

Container:register_prop('models/props_junk/cardboard_box004a.mdl', {
  name = 'container.small_box.title',
  desc = 'container.small_box.desc',
  w = 1,
  h = 1,
  open_sound = 'physics/cardboard/cardboard_box_impact_soft5.wav',
  close_sound = 'physics/cardboard/cardboard_box_impact_soft7.wav'
})

Container:register_prop('models/props_junk/TrashBin01a.mdl', {
  name = 'container.trash_bin.title',
  desc = 'container.trash_bin.desc',
  w = 3,
  h = 5,
  open_sound = 'physics/plastic/plastic_box_impact_soft3.wav',
  close_sound = 'physics/plastic/plastic_box_impact_soft1.wav'
})

Container:register_prop('models/props_junk/TrashDumpster01a.mdl', {
  name = 'container.dumpster.title',
  desc = 'container.dumpster.desc',
  w = 6,
  h = 5,
  open_sound = 'physics/metal/metal_solid_strain1.wav',
  close_sound = 'physics/metal/metal_sheet_impact_hard7.wav'
})

Container:register_prop({
  'models/props_junk/wood_crate001a.mdl',
  'models/props_junk/wood_crate001a_damaged.mdl'
},
{
  name = 'container.wooden_crate.title',
  desc = 'container.wooden_crate.desc',
  w = 5,
  h = 5,
  open_sound = 'physics/wood/wood_box_impact_soft1.wav',
  close_sound = 'physics/wood/wood_box_impact_hard5.wav'
})

Container:register_prop('models/props_junk/wood_crate002a.mdl', {
  name = 'container.big_wooden_crate.title',
  desc = 'container.big_wooden_crate.desc',
  w = 8,
  h = 5,
  open_sound = 'physics/wood/wood_box_impact_soft1.wav',
  close_sound = 'physics/wood/wood_box_impact_hard5.wav'
})

Container:register_prop({
  'models/props_lab/filecabinet02.mdl',
  'models/props_wasteland/controlroom_filecabinet001a.mdl'
},
{
  name = 'container.file_cabinet.title',
  desc = 'container.file_cabinet.desc',
  w = 2,
  h = 3,
  open_sound = 'items/ammocrate_open.wav',
  close_sound = 'items/ammocrate_close.wav'
})

Container:register_prop('models/props_wasteland/controlroom_filecabinet002a.mdl', {
  name = 'container.tall_file_cabinet.title',
  desc = 'container.tall_file_cabinet.desc',
  w = 2,
  h = 6,
  open_sound = 'items/ammocrate_open.wav',
  close_sound = 'items/ammocrate_close.wav'
})

Container:register_prop({
  'models/props_wasteland/controlroom_storagecloset001a.mdl',
  'models/props_wasteland/controlroom_storagecloset001b.mdl'
},
{
  name = 'container.storage_closet.title',
  desc = 'container.storage_closet.desc',
  w = 5,
  h = 7,
  open_sound = 'items/ammocrate_open.wav',
  close_sound = 'items/ammocrate_close.wav'
})

Container:register_prop('models/props_wasteland/kitchen_fridge001a.mdl', {
  name = 'container.large_fridge.title',
  desc = 'container.large_fridge.desc',
  w = 6,
  h = 8,
  open_sound = 'items/ammocrate_open.wav',
  close_sound = 'items/ammocrate_close.wav'
})

Container:register_prop('models/props_wasteland/kitchen_counter001c.mdl', {
  name = 'container.counter.title',
  desc = 'container.counter.desc',
  w = 5,
  h = 5,
  open_sound = 'items/ammocrate_open.wav',
  close_sound = 'items/ammocrate_close.wav'
})

Container:register_prop({
  'models/Items/ammoCrate_Rockets.mdl',
  'models/Items/ammocrate_smg1.mdl',
  'models/Items/ammocrate_ar2.mdl',
  'models/Items/ammocrate_grenade.mdl'
}, 
{
  name = 'container.metal_box.title',
  desc = 'container.metal_box.desc',
  w = 7,
  h = 4,
  open_sound = 'items/ammocrate_open.wav',
  close_sound = 'items/ammocrate_close.wav'
})

Container:register_prop('models/Items/item_item_crate.mdl', {
  name = 'container.medium_wooden_crate.title',
  desc = 'container.medium_wooden_crate.desc',
  w = 4,
  h = 4,
  open_sound = 'physics/wood/wood_box_impact_soft1.wav',
  close_sound = 'physics/wood/wood_box_impact_hard5.wav'
})
