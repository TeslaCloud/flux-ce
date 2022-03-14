Crate:describe(function(s)
  s.name        = 'Flux'
  s.version     = '0.8.0'
  s.date        = '2019-11-15'
  s.summary     = 'A gamemode framework.'
  s.description = 'A gamemode framework made primarily for database-driven roleplay gamemodes.'
  s.authors     = { 'TeslaCloud Studios', 'Meow the Cat', 'AleXXX_007', 'NightAngel', 'Zig' }
  s.email       = 'support@teslacloud.net'
  s.global      = 'Flux'
  s.website     = 'https://teslacloud.net'
  s.license     = 'MIT'

  if system.IsLinux() then
    s.depends   'colorfix'
  end

  s.depends     'pon'
  s.depends     'cable'
  s.depends     'utf8'
  s.depends     'markdown'
  s.depends     'yaml'
  s.depends     'tween'
  s.depends     'lib/flux.lua'
  s.depends     'active_record'
  s.depends     'active_network'
  s.depends     'packager'
  s.depends     'flow'
  s.depends     'gvue'

  if ENV['FLUX_ENV'] != 'production' then
    s.depends   'proofreader'
  end
end)
