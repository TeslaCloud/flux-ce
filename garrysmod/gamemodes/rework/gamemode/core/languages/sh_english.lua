--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

local lang = rw.lang:GetTable("en")

lang["#Commands_NotValid"] = "'#1' is not a valid command!";
lang["#Commands_NoAccess"] = "You do not have access to this command!";
lang["#Commands_PlayerInvalid"] = "'#1' is not a valid player!";
lang["#Commands_HigherImmunity"] = "#1 has higher immunity than you!";
lang["#Err_GroupNotValid"] = "'#1' is not a valid user group!";

lang["#KickMessage"] = "#1 has kicked #2. (#3)";
lang["#AddBotsMessage"] = "#1 has added #2 bots to the server.";
lang["#KickBotsMessage"] = "#1 has kicked all bots.";
lang["#MapRestartMessage"] = "#1 is restarting the map in #2 second(s)!";
lang["#MapChangeMessage"] = "#1 is changing the level to #2 in #3 second(s)!";

lang["#TabMenu_Expand"] = "Expand";
lang["#TabMenu_Characters"] = "Characters";
lang["#TabMenu_Inventory"] = "Inventory";
lang["#TabMenu_Settings"] = "Settings";
lang["#TabMenu_Home"] = "Home";
lang["#TabMenu_Scoreboard"] = "Scoreboard";
lang["#TabMenu_Admin"] = "Admin";

lang["#CMDDesc_Usage"] = "Syntax:";
lang["#CMDDesc_Aliases"] = "Aliases:";

lang["#KickCMD_Description"] = "Kicks player from the server.";
lang["#KickCMD_Syntax"] = "<target> [reason]";

lang["#SetGroupCMD_Description"] = "Sets player's usergroup.";
lang["#SetGroupCMD_Syntax"] = "<target> <usergroup>";
lang["#SetGroupCMD_Message"] = "#1 has set #2's user group to #3.";

lang["#DemoteCMD_Description"] = "Demote a player to user.";
lang["#DemoteCMD_Syntax"] = "<target>";
lang["#DemoteCMD_Message"] = "#1 has demoted #2 from #3 to user.";