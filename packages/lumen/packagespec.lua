Package:describe(function(s)
  s.name        = 'Lumen'
  s.version     = '1.0'
  s.date        = '2026-10-10'
  s.summary     = 'Declarative Derma interfaces from Lua templates with markup.'
  s.description = 'Lumen builds Derma interfaces from templates: Lua code with markup in it that describes '..
                  'a tree of elements. Function components with state render the tree, a reconciler maps '..
                  'it to vgui panels and keeps them up to date, and a flexbox layout engine positions them.'
  s.authors     = { 'TeslaCloud Studios', 'Luna Fox' }
  s.email       = 'support@teslacloud.net'
  s.file        = 'shared.lua'
  s.global      = 'Lumen'
  s.website     = 'https://teslacloud.net'
  s.license     = 'MIT'
end)
