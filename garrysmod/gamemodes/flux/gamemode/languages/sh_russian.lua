--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local lang = fl.lang:GetTable("ru")

do
	local vowels = {
		["а"] = true,
		["е"] = true,
		["ё"] = true,
		["у"] = true,
		["и"] = true,
		["о"] = true,
		["ы"] = true,
		["э"] = true,
		["ю"] = true,
		["я"] = true
	}

	function lang:IsVowel(char)
		return vowels[char]
	end
end

lang["#second"] = "#1 секунда"
lang["#second_2"] = "#1 секунды"
lang["#second_5"] = "#1 секунд"
lang["#minute"] = "#1 минута"
lang["#minute_2"] = "#1 минуты"
lang["#minute_5"] = "#1 минут"
lang["#hour"] = "#1 час"
lang["#hour_2"] = "#1 часа"
lang["#hour_5"] = "#1 часов"
lang["#day"] = "#1 день"
lang["#day_2"] = "#1 дня"
lang["#day_5"] = "#1 дней"
lang["#week"] = "#1 неделя"
lang["#week_2"] = "#1 недели"
lang["#week_5"] = "#1 недель"
lang["#month"] = "#1 месяц"
lang["#month_2"] = "#1 месяца"
lang["#month_5"] = "#1 месяцев"
lang["#year"] = "#1 год"
lang["#year_2"] = "#1 года"
lang["#year_5"] = "#1 лет"
lang["#permanently"] = "навсегда"
lang["#for"] = "на"

function lang:PickEnding(n)
	local ns = tostring(n)
	local ending = tonumber(ns:sub(ns:len(), ns:len()))

	if (ending) then
		if (ending > 1 and ending < 5) then
			return "_2"
		elseif (ending == 0 or ending >= 5) then
			return "_5"
		end
	end

	return ""
end

function lang:NiceTime(time)
	if (time < 60) then
		return "#second"..self:PickEnding(time)..":"..time..";", 0
	elseif (time < (60 * 60)) then
		local t = math.floor(time / 60)

		return "#minute"..self:PickEnding(time)..":"..t..";", time - t * 60
	elseif (time < (60 * 60 * 24)) then
		local t = math.floor(time / 60 / 60)

		return "#hour"..self:PickEnding(time)..":"..t..";", time - t * 60 * 60
	elseif (time < (60 * 60 * 24 * 7)) then
		local t = math.floor(time / 60 / 60 / 24)

		return "#day"..self:PickEnding(time)..":"..t..";", time - t * 60 * 60 * 24
	elseif (time < (60 * 60 * 24 * 30)) then
		local t = math.floor(time / 60 / 60 / 24 / 7)

		return "#week"..self:PickEnding(time)..":"..t..";", time - t * 60 * 60 * 24 * 7
	elseif (time < (60 * 60 * 24 * 30 * 12)) then
		local t = math.floor(time / 60 / 60 / 24 / 30)

		return "#month"..self:PickEnding(time)..":"..t..";", time - t * 60 * 60 * 24 * 30
	elseif (time >= (60 * 60 * 24 * 365)) then
		local t = math.floor(time / 60 / 60 / 24 / 365)

		return "#year"..self:PickEnding(time)..":"..t..";", time - t * 60 * 60 * 24 * 365
	else
		return "#second:"..time..";", 0
	end
end

function lang:NiceTimeFull(time)
	local out = ""
	local i = 0

	while (time > 0) do
		if (i >= 100) then break end -- fail safety

		local str, remainder = self:NiceTime(time)

		time = remainder
		out = out..str

		i = i + 1
	end

	return out
end

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

lang["#Err_NotValidEntity"] = "Вы должны смотреть на энтити!"
lang["#Err_CannotStaticThis"] = "Вы не можете сохранить этот энтити!"
lang["#Err_AlreadyStatic"] = "Этот энтити уже сохранен!"
lang["#Err_NotStatic"] = "Этот энтити не сохранен!"
lang["#Static_Added"] = "Вы сохранили этот энтити."
lang["#Static_Removed"] = "Вы убрали этот энтити из сохранения."

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

lang["#Settings_DrawLegs"] = "Draw your legs."
lang["#Settings_ToggleAutoWalk"] = "Toggle Auto-Walk"
lang["#Settings_ToggleThirdPerson"] = "Переключить вид от третьего лица"

lang["#TargetID_Information"] = "Нажмите 'E', чтобы посмотреть информацию."
lang["#TargetID_Action"] = "Нажмите 'E' для выполнения действия."

lang["#Perm_NotSet"] = "Не указано (нет)"
lang["#Perm_Allow"] = "Разрешить"
lang["#Perm_Never"] = "Никогда"
lang["#Perm_AllowOverride"] = "Разрешить (Обход)"
lang["#Perm_Error"] = "Ошибка"

lang["#Err_No_Permission"] = "У вас недостаточно прав чтобы сделать это, #1."

lang["#tool.area.name"] = "Создатель Зон"
lang["#tool.area.desc"] = "Создавайте зоны в форме многоугольников на изи."
lang["#tool.area.0"] = "ЛКМ: Добавить точку зоны, ПКМ: Создать зону."
lang["#tool.area.text"] = "ID зоны"
lang["#tool.area.height"] = "Высота"
lang["#tool.area.mode"] = "Тип"

lang["#tool.texts.name"] = "Редактор Текстов"
lang["#tool.texts.desc"] = "Добавляет 3D тексты на поверхности."
lang["#tool.texts.0"] = "ЛКМ: Добавить текст. ПКМ: Удалить текст."
lang["#tool.texts.text"] = "Текст"
lang["#tool.texts.style"] = "Стиль"
lang["#tool.texts.color"] = "Цвет"
lang["#tool.texts.extraColor"] = "Доп. Цвет"
lang["#tool.texts.scale"] = "Размер Текста"
lang["#tool.texts.fade"] = "Дистанция Отрисовки"
lang["#tool.texts.opt1"] = "Обычный Текст"
lang["#tool.texts.opt2"] = "Текст с Дальней Тенью"
lang["#tool.texts.opt3"] = "Текст с Черной Тенью"
lang["#tool.texts.opt4"] = "Текст с Двумя Тенями"
lang["#tool.texts.opt5"] = "Текст в Табличке"
lang["#tool.texts.opt6"] = "Текст в Мигающей Табличке"

lang["#tool.static.name"] = "Сохранение/Удаление Энтити"
lang["#tool.static.desc"] = "Сохраняет энтити между рестартами или удаляет его из сохранения."
lang["#tool.static.0"] = "ЛКМ: Сохранить, ПКМ: Удалить."