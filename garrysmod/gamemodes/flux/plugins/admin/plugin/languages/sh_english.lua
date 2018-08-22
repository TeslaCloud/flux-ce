local lang = fl.lang:GetTable("en")

lang["#Err_GroupNotValid"]        = "'#1' is not a valid user group!"
lang["#Err_NotBanned"]          = "Steam ID '#1' is not banned!"

lang["#FreezeBotsMessage"]        = "#1 has frozen all bots."
lang["#UnfreezeBotsMessage"]      = "#1 has unfrozen all bots."
lang["#KickMessage"]          = "#1 has kicked #2. (#3)"
lang["#BanMessage"]            = "#1 has banned #2"
lang["#UnbanMessage"]          = "#1 has unbanned #2."
lang["#AddBotsMessage"]          = "#1 has added #2 bots to the server."
lang["#KickBotsMessage"]        = "#1 has kicked all bots."
lang["#MapRestartMessage"]        = "#1 is restarting the map in #2 second(s)!"
lang["#MapChangeMessage"]        = "#1 is changing the level to #2 in #3 second(s)!"

lang["#CMDDesc_Usage"]          = "Syntax:"
lang["#CMDDesc_Aliases"]        = "Aliases:"

lang["#KickCMD_Description"]      = "Kicks player from the server."
lang["#KickCMD_Syntax"]          = "<target> [reason]"

lang["#BanCMD_Description"]        = "Ban this sucker!"
lang["#BanCMD_Syntax"]          = "<target> <duration> [reason]"

lang["#UnbanCMD_Description"]      = "Unban the specified Steam ID if it is banned."
lang["#UnbanCMD_Syntax"]        = "<target SteamID>"

lang["#SetGroupCMD_Description"]    = "Sets player's usergroup."
lang["#SetGroupCMD_Syntax"]        = "<target> <usergroup>"
lang["#SetGroupCMD_Message"]      = "#1 has set #2's user group to #3."

lang["#PlayerGroup_User"]        = "The base rank that is automatically given to the player."
lang["#PlayerGroup_Operator"]      = "Low clearance administrative rank given to assistant staff members."
lang["#PlayerGroup_Admin"]        = "An administrative rank given to trusted staff members."
lang["#PlayerGroup_Superadmin"]      = "A high level administrative rank given to the most trusted of staff members."
lang["#PlayerGroup_Root"]        = "The complete administrative rank given to the owners of the server."

lang["#DemoteCMD_Description"]      = "Demote a player to user."
lang["#DemoteCMD_Syntax"]        = "<target>"
lang["#DemoteCMD_Message"]        = "#1 has demoted #2 from #3 to user."

--[[
  PERMISSIONS - Description: Language category for all permission dialogue.
  Formatting: Begin all language references with #Perm.
--]]

lang["#Perm_NotSet"]      = "Not Set (No)"
lang["#Perm_Allow"]        = "Allow"
lang["#Perm_Never"]        = "Never"
lang["#Perm_AllowOverride"]    = "Allow (Override)"
lang["#Perm_Error"]        = "Invalid Permission"

lang["#Err_No_Permission"] = "You have no permissions to do that, #1."
