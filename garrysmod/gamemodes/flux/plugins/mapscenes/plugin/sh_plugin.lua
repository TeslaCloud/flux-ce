PLUGIN:set_global('flMapscene')

flMapscene.anim = flMapscene.anim or { rotate = 0, move = 0, delay = 10 }
flMapscene.points = flMapscene.points or {}

util.include('cl_hooks.lua')
util.include('cl_plugin.lua')
util.include('sv_plugin.lua')
