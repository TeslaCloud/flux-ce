--- Hook handlers of the theme library, registered as `Theme`. They load the default
-- theme once the local player has been initialized and reload the active theme when the code
-- is refreshed. They live in the hooks folder rather than next to the `Theme` library because
-- a code refresh clears the hook cache and only the hooks folder is included again every
-- time; the library itself is only included once.

local theme_hooks = {}

--- Loads the default theme of the schema, or the 'factory' theme if there is none.
function theme_hooks:PlayerInitialized()
  Theme.load_default()
end

--- Reloads the active theme when the code is refreshed.
function theme_hooks:OnReloaded()
  Theme.reload()
end

Plugin.remove_hooks('Theme')
Plugin.add_hooks('Theme', theme_hooks)
