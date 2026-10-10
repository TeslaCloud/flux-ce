Package:describe(function(s)
  s.name        = 'Font Awesome'
  s.version     = '7.3.1'
  s.date        = '2026-10-10'
  s.summary     = 'Font Awesome icons for the user interface.'
  s.description = 'Draws the icons of Font Awesome Free as text from the bundled fonts.'
  s.authors     = { 'Fonticons, Inc.', 'TeslaCloud Studios' }
  s.cl_files    = { 'lib/cl_fontawesome.lua', 'lib/cl_icons.lua' }
  s.website     = 'https://fontawesome.com'
  s.license     = 'file'

  for k, v in ipairs(file.Find('resource/fonts/fa-*.ttf', 'GAME')) do
    resource.AddSingleFile('resource/fonts/'..v)
  end
end)
