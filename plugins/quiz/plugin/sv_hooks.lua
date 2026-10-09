--- Server-side hooks of the Quiz plugin: collects the questions once everything has loaded,
-- sends the quiz to the players who have to take it when they join and again when its
-- questions or configs change, refuses to create or load a character for them, and receives
-- the answers they hand in.

--- Brings the clients up to date on the next tick: every player who has joined is sent the
-- quiz again or told to close it, as `Quiz:send` does. Calls made within one tick are
-- answered by a single round.
local function sync_players()
  timer.Create('fl_quiz_refresh', 0, 1, function()
    for k, v in player.Iterator() do
      if istable(v.record) and v:has_initialized() then
        Quiz:send(v)
      end
    end
  end)
end

--- Runs the RegisterQuizQuestions hook once the schema and all plugins have loaded. On a
-- code refresh the players who are on the server are then sent the questions as they are
-- now, so that nobody answers a quiz that no longer exists.
function Quiz:OnSchemaLoaded()
  --- Lets the schema and plugins add their questions to the entry quiz with
  -- `Quiz:add_question`. Called on the server once all plugins and the schema have been
  -- loaded, and again on every code refresh, before which the questions are emptied. Define
  -- the handler in a server-side file, so that the correct answers are not sent to the
  -- clients along with the code, and do not return anything from it, or the plugins after
  -- it are not asked. Code that depends on the Quiz plugin may also call
  -- `Quiz:add_question` right when it loads.
  hook.Run('RegisterQuizQuestions')

  sync_players()
end

--- Sends the quiz to a player who has joined and has to take it. This happens right after
-- the player has been sent their characters, when both their record and their client are
-- ready.
-- @param actor [Player]
function Quiz:PostRestoreCharacters(actor)
  if self:is_required(actor) then
    self:send(actor)
  end
end

--- Refuses to create a character for a player who still has to pass the quiz, and sends
-- them the quiz.
-- @param actor [Player the player the character is created for]
-- @param data [Map character creation data]
-- @return [Number CHAR_ERR_QUIZ when the player has not passed, otherwise nil]
function Quiz:PlayerCreateCharacter(actor, data)
  if self:is_required(actor) then
    self:remind(actor)

    return CHAR_ERR_QUIZ
  end
end

--- Refuses to load a character for a player who still has to pass the quiz, and sends them
-- the quiz.
-- @param actor [Player the player who wants to load the character]
-- @param character [Character the character they want to load]
-- @return [Boolean false and String the reason when the player has not passed, otherwise nil]
function Quiz:PlayerCanUseCharacter(actor, character)
  if self:is_required(actor) then
    self:remind(actor)

    return false, 'error.quiz.not_passed'
  end
end

--- Brings the clients up to date once one of the configs of the quiz has changed: on the
-- next tick, when the new value is in place, every player who has joined is sent the quiz
-- again or told to close it.
-- @param key [String config key]
-- @param old_value [Any]
-- @param new_value [Any]
function Quiz:OnConfigSet(key, old_value, new_value)
  if !isstring(key) or key:sub(1, 5) != 'quiz_' then return end

  sync_players()
end

Cable.receive('fl_quiz_submit', function(actor, answers)
  local cur_time = CurTime()

  if actor.next_quiz_submission and actor.next_quiz_submission > cur_time then return end

  actor.next_quiz_submission = cur_time + 1

  Quiz:handle_submission(actor, answers)
end)
