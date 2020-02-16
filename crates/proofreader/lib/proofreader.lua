if !Settings.experimental then return end

require_relative 'core'
require_relative 'reader'

-- Load readers
require_relative 'readers/basic'
require_relative 'readers/line_end'
require_relative 'readers/line_length'
require_relative 'readers/newline_at_end_of_file'

PR:proofread_folder('gamemodes/flux')
