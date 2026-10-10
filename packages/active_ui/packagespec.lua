Package:describe(function(s)
  s.name        = 'Active UI'
  s.version     = '1.0'
  s.date        = '2026-10-10'
  s.summary     = 'The user interface of Flux.'
  s.description = 'Active UI is the frontend of Flux: the themes and the Derma skin, the fonts and the '..
                  'scaling of the stock Derma panels, the base panels, the tab menu, the scoreboard, the '..
                  'help pages, the HUD bars, the info displays, the notifications, the HTML templates, '..
                  'the prompts and the MVC request layer that connects the panels to the server.'
  s.authors     = { 'TeslaCloud Studios', 'Meow the Cat' }
  s.email       = 'support@teslacloud.net'
  s.file        = 'shared.lua'
  s.website     = 'https://teslacloud.net'
  s.license     = 'MIT'

  s.depends     'fontawesome'
  s.depends     'flow'
end)
