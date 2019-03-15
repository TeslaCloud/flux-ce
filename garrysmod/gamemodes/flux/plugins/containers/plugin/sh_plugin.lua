PLUGIN:set_global('Container')

local stored = Container.stored or {}
Container.stored = stored

function Container:register_prop(model, data)
  stored[model] = data
end

function Container:all()
  return stored
end

util.include('cl_hooks.lua')
util.include('sv_hooks.lua')

Container:register_prop('models/props_junk/cardboard_box001a.mdl', {
  name = 'container.box.title',
  desc = 'container.box.desc',
  w = 4,
  h = 3
})
