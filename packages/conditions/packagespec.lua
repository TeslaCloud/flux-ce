Package:describe(function(s)
  s.name        = 'Conditions'
  s.version     = '1.0'
  s.date        = '2026-10-29'
  s.summary     = 'Rules about players that are edited in game and checked on the server.'
  s.description = 'Conditions are rules about a player, such as who may lock a door: a registry of '..
                  'condition types, the check of a player against a tree of conditions on the server, '..
                  'and the editor panel of such a tree with its presets.'
  s.authors     = { 'TeslaCloud Studios', 'Luna Fox' }
  s.email       = 'support@teslacloud.net'
  s.file        = 'shared.lua'
  s.global      = 'Conditions'
  s.website     = 'https://teslacloud.net'
  s.license     = 'MIT'

  s.depends     'flow'
  s.depends     'active_ui'
end)
