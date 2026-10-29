--- MapScenes shows views of the map behind the intro and the main menu.
-- Staff place camera points with the Mapscene tool, which is tied to the 'map_scenes'
-- permission; the points are saved per map and sent to every client. While the
-- `ShouldMapsceneRender` hook returns true, the client's view shows the points one after
-- another. The camera is controlled by the config keys `map_scenes_speed` (seconds spent on a
-- point), `map_scenes_animated` (glide from point to point instead of cutting) and
-- `map_scenes_rotate_speed` (how fast a view that does not glide turns).

PLUGIN:set_global('MapScenes')

MapScenes.points = MapScenes.points or {}

require_relative 'cl_hooks'
require_relative 'cl_plugin'
require_relative 'sv_plugin'

--- Registers the 'map_scenes' permission.
function MapScenes:RegisterPermissions()
  Bolt:register_permission(
    'map_scenes',
    'Manage map scenes',
    'Grants access to manage map scenes.',
    'permission.categories.level_design'
  )
end
