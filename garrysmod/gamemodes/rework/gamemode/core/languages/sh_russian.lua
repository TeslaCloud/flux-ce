--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

local lang = rw.lang:GetTable("ru")

lang["#Commands_NotValid"] = "'#1' не является командой!";
lang["#Commands_NoAccess"] = "У вас нет доступа к этой команде!";
lang["#Commands_PlayerInvalid"] = "'#1' не является игроком!";
lang["#Commands_HigherImmunity"] = "#1 имеет более высокий иммунитет, чем вы!";
lang["#Err_GroupNotValid"] = "'#1' не является группой пользователя!";

lang["#KickMessage"] = "#1 кикнул #2. (#3)";
lang["#AddBotsMessage"] = "#1 добавил #2 ботов на сервер.";
lang["#KickBotsMessage"] = "#1 кикнул всех ботов.";
lang["#MapRestartMessage"] = "#1 перезапускает карту через #2 секунд!";
lang["#MapChangeMessage"] = "#1 меняет карту на #2 через #3 секунд!";

lang["#TabMenu_Expand"] = "Развернуть";
lang["#TabMenu_Characters"] = "Персонажи";
lang["#TabMenu_Inventory"] = "Инвентарь";
lang["#TabMenu_Settings"] = "Настройки";

lang["#CMDDesc_Usage"] = "Синтаксис:";
lang["#CMDDesc_Aliases"] = "Алиасы:";

lang["#KickCMD_Description"] = "Выкидывает игрока с сервера.";
lang["#KickCMD_Syntax"] = "<игрок> [причина]";

lang["#SetGroupCMD_Description"] = "Выставляет группу пользователя игрока.";
lang["#SetGroupCMD_Syntax"] = "<игрок> <группа>";
lang["#SetGroupCMD_Message"] = "#1 выдал группу пользователя #3 #2.";

lang["#DemoteCMD_Description"] = "Понижает игрока до пользователя.";
lang["#DemoteCMD_Syntax"] = "<игрок>";
lang["#DemoteCMD_Message"] = "#1 понизил #2 с #3 до пользователя.";