--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

local lang = rw.lang:GetTable("ru")

lang["#Commands_NotValid"] = "'#1' не является командой!";
lang["#Commands_NoAccess"] = "У вас нет доступа к этой команде!";
lang["#Commands_PlayerInvalid"] = "'#1' не является игроком!";
lang["#Commands_HigherImmunity"] = "#1 имеет более высокий иммунитет, чем вы!";
lang["#Err_GroupNotValid"] = "'#1' не является группой пользователя!";

lang["#FreezeBotsMessage"] = "#1 заморозил всех ботов.";
lang["#UnfreezeBotsMessage"] = "#1 разморозил всех ботов.";
lang["#KickMessage"] = "#1 кикнул #2. (#3)";
lang["#AddBotsMessage"] = "#1 добавил #2 ботов на сервер.";
lang["#KickBotsMessage"] = "#1 кикнул всех ботов.";
lang["#MapRestartMessage"] = "#1 перезапускает карту через #2 секунд!";
lang["#MapChangeMessage"] = "#1 меняет карту на #2 через #3 секунд!";

lang["#TabMenu_Expand"] = "Развернуть";
lang["#TabMenu_Characters"] = "Персонажи";
lang["#TabMenu_Inventory"] = "Инвентарь";
lang["#TabMenu_Settings"] = "Настройки";
lang["#TabMenu_Home"] = "Домашняя страница";
lang["#TabMenu_Scoreboard"] = "Игроки";
lang["#TabMenu_Admin"] = "Админка";
lang["#TabMenu_CloseMenu"] = "Close Menu";

lang["#MainMenu_Disconnect"] = "Disconnect";
lang["#MainMenu_Settings"] = "Settings";
lang["#MainMenu_Cancel"] = "Cancel";
lang["#MainMenu_Load"] = "Load";
lang["#MainMenu_New"] = "New";

lang["#CMDDesc_Usage"] = "Синтаксис:";
lang["#CMDDesc_Aliases"] = "Алиасы:";

lang["#KickCMD_Description"] = "Выкидывает игрока с сервера.";
lang["#KickCMD_Syntax"] = "<игрок> [причина]";

lang["#SetGroupCMD_Description"] = "Выставляет группу пользователя игрока.";
lang["#SetGroupCMD_Syntax"] = "<игрок> <группа>";
lang["#SetGroupCMD_Message"] = "#1 выдал группу пользователя #3 #2.";

lang["#PlayerGroup_User"] = "The base rank that is automatically given to the player.";
lang["#PlayerGroup_Operator"] = "Low clearance administrative rank given to assistant staff members.";
lang["#PlayerGroup_Admin"] = "An administrative rank given to trusted staff members.";
lang["#PlayerGroup_Superadmin"] = "A high level administrative rank given to the most trusted of staff members.";
lang["#PlayerGroup_Owner"] = "The complete administrative rank given to the owners of the server.";

lang["#DemoteCMD_Description"] = "Понижает игрока до пользователя.";
lang["#DemoteCMD_Syntax"] = "<игрок>";
lang["#DemoteCMD_Message"] = "#1 понизил #2 с #3 до пользователя.";

lang["#WhitelistCMD_Description"] = "Add a player to a faction whitelist.";
lang["#WhitelistCMD_Syntax"] = "<target> <faction> [is faction search strict]";
lang["#WhitelistCMD_Message"] = "#1 has added #2 to the #3 whitelist.";

lang["#TakeWhitelistCMD_Description"] = "Remove a player from a faction whitelist.";
lang["#TakeWhitelistCMD_Syntax"] = "<target> <faction> [is faction search strict]";
lang["#TakeWhitelistCMD_Message"] = "#1 has removed #2 from the #3 whitelist.";

lang["#Err_WhitelistNotValid"] = "'#1' is not a valid faction!";
lang["#Err_TargetNotWhitelisted"] = "#1 is not on the #2 whitelist!";

lang["#CharSetName_Description"] = "Выставляет имя персонажа.";
lang["#CharSetName_Syntax"] = "<игрок> <новое имя>";
lang["#CharSetName_Message"] = "#1 сменил имя #2 на #3.";

lang["#Settings_Dashboard"] = "Меню";
lang["#Settings_Theme"] = "Тема";
lang["#Settings_AdminESP"] = "ESP Админа";
lang["#Settings_Binds"] = "Клавиши";
lang["#Settings_General"] = "Общее";
lang["#Settings_HUD"] = "HUD";

lang["#Settings_BackgroundURL"] = "Введите ссылку на картинку для фона.";
lang["#Settings_BackgroundColor"] = "Цвет фона TAB меню:";
lang["#Settings_MenuBackColor"] = "Цвет панелей:";
lang["#Settings_TextColor"] = "Цвет текста:";
lang["#Settings_EnableAdminESP"] = "Включить ESP администратора";
lang["#Settings_FitType"] = "Выберите как следует масштабировать картинку фона.";

lang["#Settings_Fit_Tiled"] = "Плитки";
lang["#Settings_Fit_Center"] = "Центрировать";
lang["#Settings_Fit_Fill"] = "Заполнить";
lang["#Settings_Fit_Fit"] = "Подогнать размер";

lang["#TargetID_Information"] = "Press 'E' for more information."