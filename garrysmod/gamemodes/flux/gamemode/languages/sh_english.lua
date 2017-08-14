--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local lang = fl.lang:GetTable("en")

--[[
	DURATIONS - Description: Durations used in bans system.
--]]

lang["#second"]			= "#1 second"
lang["#minute"]			= "#1 minute"
lang["#hour"]			= "#1 hour"
lang["#day"]			= "#1 day"
lang["#week"]			= "#1 week"
lang["#month"]			= "#1 month"
lang["#year"]			= "#1 year"
lang["#permanently"]	= "permanently"
lang["#for"]			= "for"
lang["#and"]			= "and"

--[[
	NOTICES - Description: Language category for all notices.
--]]

lang["#Commands_NotValid"]			= "'#1' is not a valid command!"
lang["#Commands_NoAccess"]			= "You do not have access to this command!"
lang["#Commands_PlayerInvalid"]		= "'#1' is not a valid player!"
lang["#Commands_SteamidInvalid"]	= "'#1' is not a valid Steam ID!"
lang["#Commands_HigherImmunity"]	= "#1 has higher immunity than you!"
lang["#Err_GroupNotValid"]			= "'#1' is not a valid user group!"
lang["#Err_NotBanned"]				= "Steam ID '#1' is not banned!"

lang["#FreezeBotsMessage"]			= "#1 has frozen all bots."
lang["#UnfreezeBotsMessage"]		= "#1 has unfrozen all bots."
lang["#KickMessage"]				= "#1 has kicked #2. (#3)"
lang["#BanMessage"]					= "#1 has banned #2"
lang["#UnbanMessage"]				= "#1 has unbanned #2."
lang["#AddBotsMessage"]				= "#1 has added #2 bots to the server."
lang["#KickBotsMessage"]			= "#1 has kicked all bots."
lang["#MapRestartMessage"]			= "#1 is restarting the map in #2 second(s)!"
lang["#MapChangeMessage"]			= "#1 is changing the level to #2 in #3 second(s)!"

lang["#TabMenu_Expand"]				= "Expand"
lang["#TabMenu_MainMenu"]			= "Main Menu"
lang["#TabMenu_Inventory"]			= "Inventory"
lang["#TabMenu_Settings"]			= "Settings"
lang["#TabMenu_Home"]				= "Home"
lang["#TabMenu_Scoreboard"]			= "Players"
lang["#TabMenu_Admin"]				= "Admin"
lang["#TabMenu_CloseMenu"]			= "Close Menu"

--[[
	UI/HUD ELEMENTS - Description: Language category for all hud elements.
--]]

lang["#BarText_Health"]			= "HEALTH"
lang["#BarText_Armor"]			= "ARMOR"
lang["#BarText_Respawn"]		= "WAITING TO RESPAWN..."
lang["#BarText_Getup"]			= "GETTING UP..."

lang["#MainMenu_Disconnect"]	= "Disconnect"
lang["#MainMenu_Settings"]		= "Settings"
lang["#MainMenu_Cancel"]		= "Cancel"
lang["#MainMenu_Load"]			= "Load"
lang["#MainMenu_New"]			= "New"

--[[ Character Creation ]]--

lang["#CharCreate"]					= "CREATE A CHARACTER"
lang["#CharCreateText"]				= "CHARACTER CREATION"
lang["#CharCreate_Create"]			= "CREATE"
lang["#CharCreate_ModelButton"]		= "Model"
lang["#CharCreate_FactionButton"]	= "Faction"
lang["#CharCreate_GenText"]			= "General Character Information"
lang["#CharCreate_Name"]			= "Name:"
lang["#CharCreate_Desc"]			= "Description:"
lang["#CharCreate_Gender"]			= "Gender:"
lang["#CharCreate_Gender_S"]		= "Select Gender"
lang["#CharCreate_Gender_M"]		= "Male"
lang["#CharCreate_Gender_F"]		= "Female"
lang["#CharCreate_GenFacWarning"]	= "You have to select a gender or faction first!"
lang["#CharCreate_Model_S"]			= "Select a model"
lang["#CharCreate_Fac_S"]			= "Select a faction"
lang["#CharCreat_FacTitle"]			= "Faction:"

lang["#Settings_Dashboard"]			= "Dashboard"
lang["#Settings_Theme"]				= "Theme"
lang["#Settings_AdminESP"]			= "Admin ESP"
lang["#Settings_Binds"]				= "Binds"
lang["#Settings_General"]			= "General"
lang["#Settings_HUD"]= "HUD"

lang["#Settings_BackgroundURL"]		= "Specify a URL for your background."
lang["#Settings_BackgroundColor"]	= "Select a color for the dashboard's background."
lang["#Settings_MenuBackColor"]		= "Select a color for child menu backgrounds."
lang["#Settings_TextColor"]			= "Select a color for text."
lang["#Settings_EnableAdminESP"]	= "Enable the Admin ESP."
lang["#Settings_FitType"]			= "Choose a fit for your background."
lang["#Settings_DrawBars"]			= "Draw the HUD bars."
lang["#Settings_DrawBarText"]		= "Draw text on the bars."
lang["#Settings_UseTabDash"]		= "Check to use the tab dashboard, uncheck for classic tab menu."

lang["#Settings_Fit_Tiled"]			= "Tiled"
lang["#Settings_Fit_Center"]		= "Center"
lang["#Settings_Fit_Fill"]			= "Fill"
lang["#Settings_Fit_Fit"]			= "Fit"

lang["#Settings_DrawLegs"]			= "Draw your legs."
lang["#Settings_ToggleAutoWalk"]	= "Toggle Auto-Walk"
lang["#Settings_ToggleThirdPerson"]	= "Toggle Third-Person"

--[[
	MISC COMMAND - Description: Language category for all commands.
--]]

lang["#CMDDesc_Usage"]					= "Syntax:"
lang["#CMDDesc_Aliases"]				= "Aliases:"

lang["#KickCMD_Description"]			= "Kicks player from the server."
lang["#KickCMD_Syntax"]					= "<target> [reason]"

lang["#BanCMD_Description"]				= "Ban this sucker!"
lang["#BanCMD_Syntax"]					= "<target> <duration> [reason]"

lang["#UnbanCMD_Description"]			= "Unban the specified Steam ID if it is banned."
lang["#UnbanCMD_Syntax"]				= "<target SteamID>"

lang["#SetGroupCMD_Description"]		= "Sets player's usergroup."
lang["#SetGroupCMD_Syntax"]				= "<target> <usergroup>"
lang["#SetGroupCMD_Message"]			= "#1 has set #2's user group to #3."

lang["#PlayerGroup_User"]				= "The base rank that is automatically given to the player."
lang["#PlayerGroup_Operator"]			= "Low clearance administrative rank given to assistant staff members."
lang["#PlayerGroup_Admin"]				= "An administrative rank given to trusted staff members."
lang["#PlayerGroup_Superadmin"]			= "A high level administrative rank given to the most trusted of staff members."
lang["#PlayerGroup_Root"]				= "The complete administrative rank given to the owners of the server."

lang["#DemoteCMD_Description"]			= "Demote a player to user."
lang["#DemoteCMD_Syntax"]				= "<target>"
lang["#DemoteCMD_Message"]				= "#1 has demoted #2 from #3 to user."

lang["#WhitelistCMD_Description"]		= "Add a player to a faction whitelist."
lang["#WhitelistCMD_Syntax"]			= "<target> <faction> [is faction search strict]"
lang["#WhitelistCMD_Message"]			= "#1 has added #2 to the #3 whitelist."

lang["#TakeWhitelistCMD_Description"]	= "Remove a player from a faction whitelist."
lang["#TakeWhitelistCMD_Syntax"]		= "<target> <faction> [is faction search strict]"
lang["#TakeWhitelistCMD_Message"]		= "#1 has removed #2 from the #3 whitelist."

lang["#Err_WhitelistNotValid"]			= "'#1' is not a valid faction!"
lang["#Err_TargetNotWhitelisted"]		= "#1 is not on the #2 whitelist!"

lang["#CharSetName_Description"]		= "Set character's name."
lang["#CharSetName_Syntax"]				= "<target> <new name>"
lang["#CharSetName_Message"]			= "#1 has set #2's name to #3."

lang["#Err_NotValidEntity"]				= "This is not a valid entity!"
lang["#Err_CannotStaticThis"]			= "You cannot static this entity!"
lang["#Err_AlreadyStatic"]				= "This entity is already static!"
lang["#Err_NotStatic"]					= "This entity is not static!"
lang["#Static_Added"]					= "You have added a static entity!"
lang["#Static_Removed"]					= "You have removed this static entity!"

--[[
	TARGET ID - Description: Language category for all target text.
	Formatting: Begin all language references with #TargetID.
--]]

lang["#TargetID_Information"]	= "Press `E` for more information."
lang["#TargetID_Action"]		= "Press `E` for actions."

--[[
	PERMISSIONS - Description: Language category for all permission dialogue.
	Formatting: Begin all language references with #Perm.
--]]

lang["#Perm_NotSet"]		= "Not Set (No)"
lang["#Perm_Allow"]			= "Allow"
lang["#Perm_Never"]			= "Never"
lang["#Perm_AllowOverride"]	= "Allow (Override)"
lang["#Perm_Error"]			= "Invalid Permission"

lang["#Err_No_Permission"]	= "You do not have permission to do this, #1."

--[[
	TOOLS - Description: Language category for all tools.
	Formatting: Begin all language references with #tool.
	Follow default gmod/source language formatting here.
--]]

lang["#tool.area.name"]			= "Area Tool"
lang["#tool.area.desc"]			= "Create polygonal areas easy mode."
lang["#tool.area.0"]			= "Left Click: Add Area Point, Right Click: Create Area."
lang["#tool.area.text"]			= "Area ID"
lang["#tool.area.height"]		= "Height"
lang["#tool.area.type"]			= "Type"

lang["#tool.static.name"]		= "Static Add/Remove"
lang["#tool.static.desc"]		= "Add and remove static entities."
lang["#tool.static.0"]			= "Left Click: Add, Right Click: Remove."

--[[
	Misc. Things added by plugins
--]]

lang["#PressJumpToGetup"]		= "Press the 'jump' key to get up..."

lang["#Hint_Forums"]			= "Forums"
lang["#Hint_Hints"]				= "Hints"
lang["#Hint_TAB"]				= "TAB"
lang["#Hint_Inventory"]			= "Inventory"
lang["#Hint_Commands"]			= "Commands"
lang["#Hint_Bugs"]				= "Bugs"
lang["#Hint_ForumsText"]		= "You can visit TeslaCloud forums to get support, download schemas\nand chat with fellow Flux users!"
lang["#Hint_HintsText"]			= "These hints can be disabled from clientside settings menu.\nNot in this build though."
lang["#Hint_TABText"]			= "Press 'Show Scoreboard' key (default: TAB) to open Flux's menu."
lang["#Hint_InventoryText"]		= "Drag'n'Drop an item outside of inventory screen to drop it."
lang["#Hint_CommandsText"]		= "Start typing a command in chat to see a list of all available commands\nand their syntax help."
lang["#Hint_BugsText"]			= "Encountered a bug? Have an idea that we should totally add to Flux?\nVisit our forums at TeslaCloud.net and tell us about it!"