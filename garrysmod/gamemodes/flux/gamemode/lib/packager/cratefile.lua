Crate:describe(function(s)
  s.name        'Flux Packager'
  s.version     '1.0'
  s.date        '2019-03-09'
  s.summary     'Flux package system.'
  s.description 'Flux package system with version control and dependency resolution. Also provides Luna language backend.'
  s.authors     { 'TeslaCloud Studios', 'Meow the Cat' }
  s.email       'support@teslacloud.net'
  s.files       { 'lex.lua', 'parser.lua', 'minifier.lua', 'code_generator.lua' }
  s.global      'Packager'
  s.website     'https://teslacloud.net'
  s.license     'MIT'

  s.depends     'flow'
end)
