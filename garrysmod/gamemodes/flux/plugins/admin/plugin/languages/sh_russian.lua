--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

local lang = fl.lang:GetTable("ru")

lang["#Err_GroupNotValid"]         = "'#1' не является группой пользователя!"
lang["#Err_NotBanned"]           = "Steam ID '#1' не находится в блокировке!"

lang["#FreezeBotsMessage"]         = "#1 заморозил всех ботов."
lang["#UnfreezeBotsMessage"]       = "#1 разморозил всех ботов."
lang["#KickMessage"]           = "#1 кикнул #2. (#3)"
lang["#BanMessage"]           = "#1 заблокировал #2"
lang["#UnbanMessage"]           = "#1 разблокировал #2."
lang["#AddBotsMessage"]         = "#1 добавил #2 ботов на сервер."
lang["#KickBotsMessage"]         = "#1 кикнул всех ботов."
lang["#MapRestartMessage"]         = "#1 перезапускает карту через #2 секунд!"
lang["#MapChangeMessage"]         = "#1 меняет карту на #2 через #3 секунд!"

lang["#CMDDesc_Usage"]           = "Синтаксис:"
lang["#CMDDesc_Aliases"]         = "Алиасы:"

lang["#KickCMD_Description"]       = "Выкидывает игрока с сервера."
lang["#KickCMD_Syntax"]         = "<игрок> [причина]"

lang["#BanCMD_Description"]       = "Забанить урода!"
lang["#BanCMD_Syntax"]           = "<игрок> <срок блокировки> [причина]"

lang["#UnbanCMD_Description"]       = "Разблокировать игрока с таким Steam ID если тот находится в блокировке."
lang["#UnbanCMD_Syntax"]         = "<заблокированный SteamID>"

lang["#SetGroupCMD_Description"]     = "Выставляет группу пользователя игрока."
lang["#SetGroupCMD_Syntax"]       = "<игрок> <группа>"
lang["#SetGroupCMD_Message"]       = "#1 выдал группу пользователя #3 #2."

lang["#PlayerGroup_User"]         = "Ранг, выдаваемый всем игрокам при заходе на сервер."
lang["#PlayerGroup_Operator"]       = "Административный ранг с низким уровнем доступа, для помощников администрации."
lang["#PlayerGroup_Admin"]         = "Административный ранг для проверенных админов."
lang["#PlayerGroup_Superadmin"]     = "Административный ранг высшего уровня, имеющий доступ к большинству функций сервера."
lang["#PlayerGroup_Root"]         = "Ранг с полным доступом ко всему."

lang["#DemoteCMD_Description"]       = "Понижает игрока до пользователя."
lang["#DemoteCMD_Syntax"]         = "<игрок>"
lang["#DemoteCMD_Message"]         = "#1 понизил #2 с #3 до пользователя."

--[[
  PERMISSIONS - Description: Language category for all permission dialogue.
  Formatting: Begin all language references with #Perm.
--]]

lang["#Perm_NotSet"]       = "Не указано (нет)"
lang["#Perm_Allow"]       = "Разрешить"
lang["#Perm_Never"]       = "Никогда"
lang["#Perm_AllowOverride"]   = "Разрешить (Обход)"
lang["#Perm_Error"]       = "Ошибка"

lang["#Err_No_Permission"] = "У вас недостаточно прав чтобы сделать это, #1."
