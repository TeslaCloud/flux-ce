class "CCommand"

CCommand.id = "undefined"
CCommand.name = "Unknown"
CCommand.description = "An undescribed command."
CCommand.Syntax = "[none]"
CCommand.Immunity = false
CCommand.PlayerArg = nil
CCommand.Arguments = 0
CCommand.noConsole = false

function CCommand:CCommand(id)
  self.id = id
end

function CCommand:OnRun() end

function CCommand:__tostring()
  return "Command ["..self.id.."]["..self.name.."]"
end

function CCommand:register()
  fl.command:Create(self.id, self)
end

Command = CCommand
