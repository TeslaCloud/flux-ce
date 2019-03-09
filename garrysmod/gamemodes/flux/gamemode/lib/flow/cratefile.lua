Crate:describe(function(s)
  s.name        'Flow'
  s.version     '1.0'
  s.date        '2019-03-09'
  s.summary     'A collection of utility libraries.'
  s.description 'A collection of the utility libraries that Flux relies on. They provide a lot of misc. functions and aliases for development convenience.'
  s.author      'TeslaCloud Studios'
  s.email       'support@teslacloud.net'
  s.files       {
    'sh_aliases.lua', 'sh_string.lua', 'sh_utils.lua', 'sh_color.lua',
    'sh_math.lua', 'sh_player.lua', 'sh_table.lua', 'sh_wrappers.lua',
    'cl_utils.lua', 'inflector/inflector.lua', 'inflector/inflections.lua'
  }
  s.global      'Flow'
  s.website     'https://teslacloud.net'
  s.license     'MIT'
end)
