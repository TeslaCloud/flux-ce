Package:describe(function(s)
  s.name        = 'Bolt'
  s.version     = '1.0'
  s.date        = '2026-10-29'
  s.summary     = 'The admin mod of Flux.'
  s.description = 'Bolt gives every player a role with an immunity level and a set of permissions, '..
                  'answers the permission checks of Flux with them, the permissions set on the player '..
                  'and on their active character included, keeps bans in the database, and adds the '..
                  'commands and the Admin entry of the tab menu with which staff manage players, roles, '..
                  'permissions, bans, configs and plugins.'
  s.authors     = { 'TeslaCloud Studios', 'Luna Fox' }
  s.email       = 'support@teslacloud.net'
  s.file        = 'shared.lua'
  s.global      = 'Bolt'
  s.website     = 'https://teslacloud.net'
  s.license     = 'MIT'

  s.depends     'flow'
  s.depends     'active_record'
  s.depends     'active_ui'
  s.depends     'cami'
end)
