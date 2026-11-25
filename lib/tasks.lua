--- The boot of Flux in fpkg's tasks, included by the `environment` task of the `taskspec.lua` of
-- the `flux` package once it has set `FLUX_PATH`.
-- Runs the first stages of the game's boot (`lib/start.lua`), then walks the packages of the
-- project in the order the server includes them, with the dependencies their specifications
-- give in the environment Flux runs in (see `Package:walk`), and registers their migrations,
-- which `Package:add_migrations` keeps until ActiveRecord is in, as it does on the server. Then
-- it includes the dependencies of the `flux` package in the order its specification lists them,
-- as the server does, up to `active_record`: that is what tasks need, while the packages after
-- it need the game. Reading the specification of `flux` gives `Flux.get_version` its version and
-- adds the folder of its packages to the search paths. Last it registers the migrations of the
-- plugins and of the schema the server loads (see `Plugin.walk_schema`). No gamemode, plugin or
-- schema code runs and the database is not connected.
-- Returns true once Flux is booted; an error in a stage is reported and stops the boot.

if !include(FLUX_PATH..'lib/start.lua') then return false end

Package:walk(engine.ActiveGamemode(), folder -> Package:add_migrations(folder))
Package:include_dependencies(Package:read('flux'), 'active_record')
Plugin.walk_schema(folder -> Package:add_migrations(folder))

return true
