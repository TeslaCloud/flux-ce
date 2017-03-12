--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local lang = fl.lang:GetTable("ru")

lang["#Commands_NotValid"] = "'#1' не является командой!"
lang["#Commands_NoAccess"] = "У вас нет доступа к этой команде!"
lang["#Commands_PlayerInvalid"] = "'#1' не является игроком!"
lang["#Commands_HigherImmunity"] = "#1 имеет более высокий иммунитет, чем вы!"
lang["#Err_GroupNotValid"] = "'#1' не является группой пользователя!"

lang["#FreezeBotsMessage"] = "#1 заморозил всех ботов."
lang["#UnfreezeBotsMessage"] = "#1 разморозил всех ботов."
lang["#KickMessage"] = "#1 кикнул #2. (#3)"
lang["#AddBotsMessage"] = "#1 добавил #2 ботов на сервер."
lang["#KickBotsMessage"] = "#1 кикнул всех ботов."
lang["#MapRestartMessage"] = "#1 перезапускает карту через #2 секунд!"
lang["#MapChangeMessage"] = "#1 меняет карту на #2 через #3 секунд!"

lang["#TabMenu_Expand"] = "Развернуть"
lang["#TabMenu_Characters"] = "Персонажи"
lang["#TabMenu_Inventory"] = "Инвентарь"
lang["#TabMenu_Settings"] = "Настройки"
lang["#TabMenu_Home"] = "Домашняя страница"
lang["#TabMenu_Scoreboard"] = "Игроки"
lang["#TabMenu_Admin"] = "Админка"
lang["#TabMenu_CloseMenu"] = "Закрыть"

lang["#BarText_Health"] = "ЗДОРОВЬЕ"
lang["#BarText_Armor"] = "БРОНЯ"
lang["#BarText_Respawn"] = "ВОЗРОЖДЕНИЕ..."

lang["#MainMenu_Disconnect"] = "Отключиться"
lang["#MainMenu_Settings"] = "Настройки"
lang["#MainMenu_Cancel"] = "Отменить"
lang["#MainMenu_Load"] = "Загрузить"
lang["#MainMenu_New"] = "Создать"

lang["#CMDDesc_Usage"] = "Синтаксис:"
lang["#CMDDesc_Aliases"] = "Алиасы:"

lang["#KickCMD_Description"] = "Выкидывает игрока с сервера."
lang["#KickCMD_Syntax"] = "<игрок> [причина]"

lang["#SetGroupCMD_Description"] = "Выставляет группу пользователя игрока."
lang["#SetGroupCMD_Syntax"] = "<игрок> <группа>"
lang["#SetGroupCMD_Message"] = "#1 выдал группу пользователя #3 #2."

lang["#PlayerGroup_User"] = "Ранг, выдаваемый всем игрокам при заходе на сервер."
lang["#PlayerGroup_Operator"] = "Административный ранг с низким уровнем доступа, для помощников администрации."
lang["#PlayerGroup_Admin"] = "Административный ранг для проверенных админов."
lang["#PlayerGroup_Superadmin"] = "Административный ранг высшего уровня, имеющий доступ к большинству функций сервера."
lang["#PlayerGroup_Owner"] = "Ранг с полным доступом ко всему."

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

lang["#Settings_Dashboard"] = "Меню"
lang["#Settings_Theme"] = "Тема"
lang["#Settings_AdminESP"] = "ESP Админа"
lang["#Settings_Binds"] = "Клавиши"
lang["#Settings_General"] = "Общее"
lang["#Settings_HUD"] = "HUD"

lang["#Settings_BackgroundURL"] = "Введите ссылку на картинку для фона."
lang["#Settings_BackgroundColor"] = "Цвет фона TAB меню:"
lang["#Settings_MenuBackColor"] = "Цвет панелей:"
lang["#Settings_TextColor"] = "Цвет текста:"
lang["#Settings_EnableAdminESP"] = "Включить ESP администратора"
lang["#Settings_FitType"] = "Выберите как следует масштабировать картинку фона."
lang["#Settings_DrawBars"] = "Отрисовывать полоски в HUD'е (здоровье, броня, и.т.п)."
lang["#Settings_DrawBarText"] = "Отрисовывать текст на полосках."
lang["#Settings_UseTabDash"] = "Выберите, чтобы использовать дэшборд-меню, снимите галочку, чтобы использовать классический вид."

lang["#Settings_Fit_Tiled"] = "Плитки"
lang["#Settings_Fit_Center"] = "Центрировать"
lang["#Settings_Fit_Fill"] = "Заполнить"
lang["#Settings_Fit_Fit"] = "Подогнать размер"

lang["#TargetID_Information"] = "Нажмите 'E', чтобы посмотреть информацию."
lang["#TargetID_Action"] = "Нажмите 'E' для выполнения действия."

lang["#tool.area.name"] = "Создатель Зон";
lang["#tool.area.desc"] = "Создавайте зоны в форме многоугольников на изи.";
lang["#tool.area.0"] = "ЛКМ: Добавить точку зоны, ПКМ: Создать зону.";
lang["#tool.area.text"] = "ID зоны";
lang["#tool.area.height"] = "Высота";
lang["#tool.area.mode"] = "Тип";