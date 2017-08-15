--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local lang = fl.lang:GetTable("ru")

lang["#Commands_NotValid"] = "'#1' не является командой!"
lang["#Commands_NoAccess"] = "У вас нет доступа к этой команде!"
lang["#Commands_PlayerInvalid"] = "'#1' не является игроком!"
lang["#Commands_SteamidInvalid"] = "'#1' не является действительным Steam ID!"
lang["#Commands_HigherImmunity"] = "#1 имеет более высокий иммунитет, чем вы!"
lang["#Err_GroupNotValid"] = "'#1' не является группой пользователя!"
lang["#Err_NotBanned"] = "Steam ID '#1' не находится в блокировке!"

lang["#FreezeBotsMessage"] = "#1 заморозил всех ботов."
lang["#UnfreezeBotsMessage"] = "#1 разморозил всех ботов."
lang["#KickMessage"] = "#1 кикнул #2. (#3)"
lang["#BanMessage"] = "#1 заблокировал #2"
lang["#UnbanMessage"] = "#1 разблокировал #2."
lang["#AddBotsMessage"] = "#1 добавил #2 ботов на сервер."
lang["#KickBotsMessage"] = "#1 кикнул всех ботов."
lang["#MapRestartMessage"] = "#1 перезапускает карту через #2 секунд!"
lang["#MapChangeMessage"] = "#1 меняет карту на #2 через #3 секунд!"

lang["#CMDDesc_Usage"] = "Синтаксис:"
lang["#CMDDesc_Aliases"] = "Алиасы:"

lang["#KickCMD_Description"] = "Выкидывает игрока с сервера."
lang["#KickCMD_Syntax"] = "<игрок> [причина]"

lang["#BanCMD_Description"] = "Забанить урода!"
lang["#BanCMD_Syntax"] = "<игрок> <срок блокировки> [причина]"

lang["#UnbanCMD_Description"] = "Разблокировать игрока с таким Steam ID если тот находится в блокировке."
lang["#UnbanCMD_Syntax"] = "<заблокированный SteamID>"

lang["#SetGroupCMD_Description"] = "Выставляет группу пользователя игрока."
lang["#SetGroupCMD_Syntax"] = "<игрок> <группа>"
lang["#SetGroupCMD_Message"] = "#1 выдал группу пользователя #3 #2."

lang["#PlayerGroup_User"] = "Ранг, выдаваемый всем игрокам при заходе на сервер."
lang["#PlayerGroup_Operator"] = "Административный ранг с низким уровнем доступа, для помощников администрации."
lang["#PlayerGroup_Admin"] = "Административный ранг для проверенных админов."
lang["#PlayerGroup_Superadmin"] = "Административный ранг высшего уровня, имеющий доступ к большинству функций сервера."
lang["#PlayerGroup_Root"] = "Ранг с полным доступом ко всему."

lang["#DemoteCMD_Description"] = "Понижает игрока до пользователя."
lang["#DemoteCMD_Syntax"] = "<игрок>"
lang["#DemoteCMD_Message"] = "#1 понизил #2 с #3 до пользователя."

lang["#WhitelistCMD_Description"] = "Дает игроку доступ к фракции."
lang["#WhitelistCMD_Syntax"] = "<игрок> <фракция> [строгий режим поиска]"
lang["#WhitelistCMD_Message"] = "#1 дал #2 доступ к фракции #3."

lang["#TakeWhitelistCMD_Description"] = "Убирает у игрока доступ к фракции."
lang["#TakeWhitelistCMD_Syntax"] = "<игрок> <фракция> [строгий режим поиска]"
lang["#TakeWhitelistCMD_Message"] = "#1 забрал у #2 доступ к фракции #3."

lang["#Err_WhitelistNotValid"] = "'#1' не является фракцией!"
lang["#Err_TargetNotWhitelisted"] = "У #1 нет доступа к фракции #2!"

lang["#CharSetName_Description"] = "Выставляет имя персонажа."
lang["#CharSetName_Syntax"] = "<игрок> <новое имя>"
lang["#CharSetName_Message"] = "#1 сменил имя #2 на #3."

lang["#Perm_NotSet"] = "Не указано (нет)"
lang["#Perm_Allow"] = "Разрешить"
lang["#Perm_Never"] = "Никогда"
lang["#Perm_AllowOverride"] = "Разрешить (Обход)"
lang["#Perm_Error"] = "Ошибка"

lang["#Err_No_Permission"] = "У вас недостаточно прав чтобы сделать это, #1."