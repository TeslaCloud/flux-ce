--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local lang = fl.lang:GetTable("en")

lang["#Commands_NotValid"] = "'#1' is not a valid command!"
lang["#Commands_NoAccess"] = "You do not have access to this command!"
lang["#Commands_PlayerInvalid"] = "'#1' is not a valid player!"
lang["#Commands_HigherImmunity"] = "#1 has higher immunity than you!"
lang["#Err_GroupNotValid"] = "'#1' is not a valid user group!"

lang["#FreezeBotsMessage"] = "#1 has frozen all bots."
lang["#UnfreezeBotsMessage"] = "#1 has unfrozen all bots."
lang["#KickMessage"] = "#1 has kicked #2. (#3)"
lang["#AddBotsMessage"] = "#1 has added #2 bots to the server."
lang["#KickBotsMessage"] = "#1 has kicked all bots."
lang["#MapRestartMessage"] = "#1 is restarting the map in #2 second(s)!"
lang["#MapChangeMessage"] = "#1 is changing the level to #2 in #3 second(s)!"

lang["#TabMenu_Expand"] = "Expand"
lang["#TabMenu_MainMenu"] = "Main Menu"
lang["#TabMenu_Inventory"] = "Inventory"
lang["#TabMenu_Settings"] = "Settings"
lang["#TabMenu_Home"] = "Home"
lang["#TabMenu_Scoreboard"] = "Players"
lang["#TabMenu_Admin"] = "Admin"
lang["#TabMenu_CloseMenu"] = "Close Menu"

lang["#BarText_Health"] = "HEALTH"
lang["#BarText_Armor"] = "ARMOR"
lang["#BarText_Respawn"] = "YOU WILL BE RESPAWNED SHORTLY"

lang["#MainMenu_Disconnect"] = "Disconnect"
lang["#MainMenu_Settings"] = "Settings"
lang["#MainMenu_Cancel"] = "Cancel"
lang["#MainMenu_Load"] = "Load"
lang["#MainMenu_New"] = "New"

lang["#CMDDesc_Usage"] = "Syntax:"
lang["#CMDDesc_Aliases"] = "Aliases:"

lang["#KickCMD_Description"] = "Kicks player from the server."
lang["#KickCMD_Syntax"] = "<target> [reason]"

lang["#SetGroupCMD_Description"] = "Sets player's usergroup."
lang["#SetGroupCMD_Syntax"] = "<target> <usergroup>"
lang["#SetGroupCMD_Message"] = "#1 has set #2's user group to #3."

lang["#PlayerGroup_User"] = "The base rank that is automatically given to the player."
lang["#PlayerGroup_Operator"] = "Low clearance administrative rank given to assistant staff members."
lang["#PlayerGroup_Admin"] = "An administrative rank given to trusted staff members."
lang["#PlayerGroup_Superadmin"] = "A high level administrative rank given to the most trusted of staff members."
lang["#PlayerGroup_Owner"] = "The complete administrative rank given to the owners of the server."

lang["#DemoteCMD_Description"] = "Demote a player to user."
lang["#DemoteCMD_Syntax"] = "<target>"
lang["#DemoteCMD_Message"] = "#1 has demoted #2 from #3 to user."

lang["#WhitelistCMD_Description"] = "Add a player to a faction whitelist."
lang["#WhitelistCMD_Syntax"] = "<target> <faction> [is faction search strict]"
lang["#WhitelistCMD_Message"] = "#1 has added #2 to the #3 whitelist."

lang["#TakeWhitelistCMD_Description"] = "Remove a player from a faction whitelist."
lang["#TakeWhitelistCMD_Syntax"] = "<target> <faction> [is faction search strict]"
lang["#TakeWhitelistCMD_Message"] = "#1 has removed #2 from the #3 whitelist."

lang["#Err_WhitelistNotValid"] = "'#1' is not a valid faction!"
lang["#Err_TargetNotWhitelisted"] = "#1 is not on the #2 whitelist!"

lang["#CharSetName_Description"] = "Set character's name."
lang["#CharSetName_Syntax"] = "<target> <new name>"
lang["#CharSetName_Message"] = "#1 has set #2's name to #3."

lang["#Settings_Dashboard"] = "Dashboard"
lang["#Settings_Theme"] = "Theme"
lang["#Settings_AdminESP"] = "Admin ESP"
lang["#Settings_Binds"] = "Binds"
lang["#Settings_General"] = "General"
lang["#Settings_HUD"] = "HUD"

lang["#Settings_BackgroundURL"] = "Specify a URL for your background."
lang["#Settings_BackgroundColor"] = "Select a color for the dashboard's background."
lang["#Settings_MenuBackColor"] = "Select a color for child menu backgrounds."
lang["#Settings_TextColor"] = "Select a color for text."
lang["#Settings_EnableAdminESP"] = "Enable the Admin ESP."
lang["#Settings_FitType"] = "Choose a fit for your background."
lang["#Settings_DrawBars"] = "Draw the HUD bars."
lang["#Settings_DrawBarText"] = "Draw text on the bars."
lang["#Settings_UseTabDash"] = "Check to use the tab dashboard, uncheck for classic tab menu."

lang["#Settings_Fit_Tiled"] = "Tiled"
lang["#Settings_Fit_Center"] = "Center"
lang["#Settings_Fit_Fill"] = "Fill"
lang["#Settings_Fit_Fit"] = "Fit"

lang["#TargetID_Information"] = "Press `E` for more information."
lang["#TargetID_Action"] = "Press `E` for actions."

lang["#tool.area.name"] = "Area Tool";
lang["#tool.area.desc"] = "Create polygonal areas easy mode.";
lang["#tool.area.0"] = "Left Click: Add Area Point, Right Click: Create Area.";
lang["#tool.area.text"] = "Area ID";
lang["#tool.area.height"] = "Height";
lang["#tool.area.type"] = "Type";