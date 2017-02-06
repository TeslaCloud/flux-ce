TOOL.Category = "Rework"
TOOL.Name = "Test Tool"
TOOL.Command = nil
TOOL.ConfigName = "" --Setting this means that you do not have to create external configuration files to define the layout of the tool config-hud 
 
function TOOL:LeftClick(trace)
 	PrintTable(trace)

 	return true
end
 
function TOOL:RightClick(trace)
end