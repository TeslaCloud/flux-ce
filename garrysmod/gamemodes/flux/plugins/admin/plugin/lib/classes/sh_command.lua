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

function Command:notify(permision, message, arguments, color)
  local player_list

  if isstring(permission) then
    player_list = table.map(player_list, function(v) return v:can(permission) end)
  elseif istable(permission) then
    player_list = permission
  elseif IsValid(permission) then
    player_list = { permission }
  else
    player_list = player.GetAll()
  end

  for k, v in ipairs(player_list) do
    v:notify(message, arguments, color)
  end
end

function Command:notify_admin(permision, message, arguments)
  self:notify(permission, message, arguments, Color(255, 128, 128))
end

function Command:register()
  fl.command:create(self.id, self)
end
