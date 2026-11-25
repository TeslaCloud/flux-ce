--- The boot of Flux in fpkg's tasks, included by the `environment` task of the `taskspec.lua` of
-- the `flux` package once it has set `FLUX_PATH`.
-- Runs the first stages of the game's boot (`lib/start.lua`), reads the specification of the
-- `flux` package, which gives `Flux.get_version` its version and adds the folder of its packages
-- to the search paths, then includes the dependencies of `flux` in the order the specification
-- lists them, as the server does, up to `active_record`: that is what tasks need, while the
-- packages after it need the game. No gamemode, plugin or schema code runs and the database is
-- not connected. Last it registers the migrations the server would install, in the order the
-- server registers them: those of every package of the project (`fpkg.packages`, which lists
-- them in the order Flux includes them), then those of the plugins and of the schema the server
-- loads (see `Plugin.walk_schema`).
-- Returns true once Flux is booted; an error in a stage is reported and stops the boot.

if !include(FLUX_PATH..'lib/start.lua') then return false end

Package:include_dependencies(Package:read('flux'), 'active_record')

for _, entry in ipairs(fpkg.packages) do
  Package:add_migrations(entry.path)
end

Plugin.walk_schema(folder -> Pipeline.include_folder('migrations', folder..'/migrations/'))

return true
