class 'Command'

Command.id = 'undefined'
Command.name = 'Unknown'
Command.description = 'An undescribed command.'
Command.syntax = '[-]'
Command.immunity = false
Command.player_arg = nil
Command.arguments = 0
Command.no_console = false

function Command:__tostring()
  return 'Command ['..self.id..']['..self.name..']'
end

function Command:init(id)
  self.id = id
end

function Command:on_run() end

function Command:register()
  fl.command:create(self.id, self)
end
