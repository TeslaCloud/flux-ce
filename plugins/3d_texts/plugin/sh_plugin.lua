--- 3D Texts lets staff put texts and pictures on the surfaces of the map.
-- They are placed and removed with the Text Tool and the Picture Placer of the tool gun, or
-- from code with `SurfaceText:add_text` and `SurfaceText:add_picture`. The server keeps
-- them in `SurfaceText.texts` and `SurfaceText.pictures`, saves them with the plugin data
-- and sends them to every client, which draws them in the world and fades them out with
-- distance.

PLUGIN:set_global('SurfaceText')

SurfaceText.texts = SurfaceText.texts or {}
SurfaceText.pictures = SurfaceText.pictures or {}

require_relative 'cl_hooks'
require_relative 'cl_plugin'
require_relative 'sv_hooks'
require_relative 'sv_plugin'

--- Registers the 'manage_texts' and 'manage_pictures' level design permissions.
function SurfaceText:RegisterPermissions()
  Bolt:register_permission('manage_texts', nil, nil, 'permission.categories.level_design')
  Bolt:register_permission('manage_pictures', nil, nil, 'permission.categories.level_design')
end
