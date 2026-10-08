--- Mapscenes shows views of the map behind the intro and the main menu.
-- Staff place camera points with the Mapscene tool, which is tied to the 'mapscenes'
-- permission; the points are saved per map and sent to every client. While the
-- `ShouldMapsceneRender` hook returns true, the client's view shows the points one after
-- another. The camera is controlled by the config keys `mapscenes_speed` (seconds spent on a
-- point), `mapscenes_animated` (glide from point to point instead of cutting) and
-- `mapscenes_rotate_speed` (how fast a view that does not glide turns).

PLUGIN:set_global('Mapscenes')

Mapscenes.points = Mapscenes.points or {}

require_relative 'cl_hooks'
require_relative 'cl_plugin'
require_relative 'sv_plugin'

--- Registers the 'mapscenes' permission.
function Mapscenes:RegisterPermissions()
  Bolt:register_permission(
    'mapscenes',
    'Manage mapscenes',
    'Grants access to manage mapscenes.',
    'permission.categories.level_design',
    'moderator'
  )
end
