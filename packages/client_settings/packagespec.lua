Package:describe(function(s)
  s.name        = 'Client Settings'
  s.version     = '1.0'
  s.date        = '2026-10-29'
  s.summary     = 'Options of their own for every player.'
  s.description = 'Client Settings gives every player options that they change in the Settings tab of '..
                  'the tab menu and that are kept in the data store of their client: a registry of '..
                  'settings and their types, the values of the local player, the networked settings '..
                  'that the server reads with Player:get_setting, and the settings menu.'
  s.authors     = { 'TeslaCloud Studios', 'Luna Fox' }
  s.email       = 'support@teslacloud.net'
  s.file        = 'shared.lua'
  s.global      = 'ClientSettings'
  s.website     = 'https://teslacloud.net'
  s.license     = 'MIT'

  s.depends     'flow'
  s.depends     'active_ui'
end)
