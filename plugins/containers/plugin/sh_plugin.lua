--- Containers turns props with certain models into storage for items.
-- A model is registered with `Containers:register_prop` together with the size of its
-- inventory, its name, its description and its sounds; common furniture, crates and boxes of
-- Half-Life 2 are registered in `lib/sh_default_props.lua`. A prop that is spawned with such a
-- model becomes persistent, shows its name when it is looked at and can be opened from its
-- interaction menu by a player within reach of it. Its inventory is created the first time it
-- is opened, or when the map starts if it holds items, and is closed for a player who moves
-- out of reach. The items are saved in the database as being in the container, which the prop
-- knows by the number in its `container_id` field, and are loaded along with the other items
-- of the map.
--
-- Staff can give a container a name of its own, a message that is shown to whoever opens it
-- and a password that has to be entered before it opens, and fill it with random items.
-- All of this is done with the Container Tool, which needs the `manage_containers`
-- permission (and `fill_containers` to fill), or from code with
-- `Containers:set_container_name`, `Containers:set_container_message`,
-- `Containers:set_container_password` and `Containers:fill`. The name, the message and the
-- password are kept on the prop in its `container_name`, `container_message` and
-- `container_password` fields, so they are saved with it, as is its `container_id`. A
-- wrong password makes the player wait for `containers_password_delay` seconds before the
-- next attempt.
--
-- Random items are picked among all registered items but the bases and those that set
-- `ITEM.lootable = false`, optionally from one item category.
--
-- When a container prop is removed, its items are destroyed with it, or dropped on the
-- ground if the `containers_spill_items` config is on.
--
-- Hooks: `PlayerCanOpenContainer` and `ShouldAskContainerPassword` decide who opens a
-- container and who has to enter its password, `PlayerEnteredContainerPassword` tells about
-- every entered password, `PreContainerOpen` is run before a container is shown to a player
-- and `OnContainerRemoved` after the items of a removed container have been dealt with.

PLUGIN:set_global('Containers')

require_relative 'cl_hooks'
require_relative 'sv_hooks'
require_relative 'sv_plugin'

--- Registers the 'manage_containers' and 'fill_containers' level design permissions.
function Containers:RegisterPermissions()
  Bolt:register_permission('manage_containers', nil, nil, 'permission.categories.level_design')
  Bolt:register_permission('fill_containers', nil, nil, 'permission.categories.level_design')
end
