--- Tasks of the `flux` package, which fpkg runs without the game server.
-- `environment` boots Flux as far as tasks need (see `lib/tasks.lua`): it is the prerequisite of
-- every task that uses Flux, such as the database tasks of ActiveRecord. It has no description,
-- so `fpkg tasks` lists it only with `--all`.

local flux_path = TASKSPEC.path

task('environment', function()
  FLUX_PATH = flux_path

  if include(flux_path..'lib/tasks.lua') != true then
    error('Flux could not boot, see the error above', 0)
  end
end)
