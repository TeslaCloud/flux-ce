--- Server side of the Quiz plugin: the questions, the grading of answers and the record of
-- who has passed.
-- The questions are kept in `Quiz.questions` by ID and in `Quiz.question_ids` in the order
-- they were added, which is the order the players see them in. Both are emptied whenever
-- this file is loaded, so that a code refresh starts from the questions the code registers.
--
-- A player who has passed has the signature of the questions in the 'quiz_passed' key of
-- their persistent data (`Player:get_player_data`). The 'quiz_retry_at' key holds the
-- `os.time` at which a player who failed may try again.

Quiz.questions = {}
Quiz.question_ids = {}
Quiz.signature = nil

Cable.check_networked_string('fl_quiz_open')
Cable.check_networked_string('fl_quiz_close')
Cable.check_networked_string('fl_quiz_result')

--- Reports a question that could not be added.
-- @param id [Any ID the question was to be added under]
-- @param reason [String what is wrong with it]
local function refuse_question(id, reason)
  ErrorNoHalt("Quiz: the question '"..tostring(id).."' was not added: "..reason..'\n')
end

--- Adds a question to the quiz, or replaces the question that has the same ID. Server only:
-- call it from a server-side file, so that the correct answer is not sent to the clients
-- along with the code. A question that is not valid is reported in the console and left
-- out.
-- ```
-- Quiz:add_question('safezone', {
--   text = 'Is it allowed to attack a player at the train station?',
--   options = { 'Yes', 'No', 'Only with a reason' },
--   answer = 2
-- })
-- ```
-- @param id [String unique ID of the question]
-- @param data [Map the question: text (String, a text or a language phrase), options
--   (List<String> at least two answer options, texts or language phrases, in the order they
--   are shown) and answer (Number position of the correct option, or List<Number> when
--   several options are accepted)]
-- @return [Map the stored question with the id, text, options and answers (Map of accepted
--   option positions) fields, or nil when it was not added]
function Quiz:add_question(id, data)
  if !isstring(id) or id == '' then
    return refuse_question(id, 'the ID has to be a string that is not empty.')
  end

  if !istable(data) or !isstring(data.text) or data.text == '' then
    return refuse_question(id, 'it has no text.')
  end

  if !istable(data.options) or #data.options < 2 then
    return refuse_question(id, 'it needs at least two options.')
  end

  local options, answers = {}, {}
  local accepted = istable(data.answer) and data.answer or { data.answer }

  for k, v in ipairs(data.options) do
    options[k] = tostring(v)
  end

  for k, v in ipairs(accepted) do
    if !isnumber(v) or options[v] == nil then
      return refuse_question(id, 'its answer has to be the position of one of its options.')
    end

    answers[v] = true
  end

  if next(answers) == nil then
    return refuse_question(id, 'it has no answer.')
  end

  if !self.questions[id] then
    table.insert(self.question_ids, id)
  end

  local question = {
    id = id,
    text = data.text,
    options = options,
    answers = answers
  }

  self.questions[id] = question
  self.signature = nil

  return question
end

--- Removes a question from the quiz. Server only.
-- @param id [String ID of the question]
function Quiz:remove_question(id)
  if !self.questions[id] then return end

  self.questions[id] = nil
  self.signature = nil

  table.RemoveByValue(self.question_ids, id)
end

--- Returns a question of the quiz. Server only.
-- @param id [String ID of the question]
-- @return [Map the question with the id, text, options and answers fields, or nil]
function Quiz:get_question(id)
  return self.questions[id]
end

--- Returns the questions of the quiz in the order they were added. Server only.
-- @return [List<Map> questions with the id, text, options and answers fields]
function Quiz:get_questions()
  local questions = {}

  for k, v in ipairs(self.question_ids) do
    questions[k] = self.questions[v]
  end

  return questions
end

--- Returns how many questions the quiz has. Server only.
-- @return [Number]
function Quiz:get_question_count()
  return #self.question_ids
end

--- Returns the questions the way they are sent to a client: the ID, the text and the
-- options of each, without the answers. Server only.
-- @return [List<Map> questions with the id, text and options fields]
function Quiz:to_networkable()
  local networkable = {}

  for k, v in ipairs(self.question_ids) do
    local question = self.questions[v]

    networkable[k] = {
      id = question.id,
      text = question.text,
      options = question.options
    }
  end

  return networkable
end

--- Returns the signature of the current set of questions: a short string that changes when a
-- question is added or removed or when the text or the options of one change. The order of
-- the questions and their correct answers do not count. Players who have passed are
-- remembered by it, and since their data is networked, leaving the answers out keeps the
-- signature from giving them away. Server only.
-- @return [String]
function Quiz:get_signature()
  if !self.signature then
    local ids = table.Copy(self.question_ids)
    local parts = {}

    table.sort(ids)

    for k, v in ipairs(ids) do
      local question = self.questions[v]

      table.insert(parts, v)
      table.insert(parts, question.text)
      table.insert(parts, table.concat(question.options, '\n'))
    end

    self.signature = #ids..':'..util.CRC(table.concat(parts, '\n'))
  end

  return self.signature
end

--- Checks whether an answer to a question is correct. Server only.
-- @param id [String ID of the question]
-- @param answer [Number position of the chosen option]
-- @return [Boolean false when the answer is wrong or there is no such question]
function Quiz:is_answer_correct(id, answer)
  local question = self.questions[id]

  return question != nil and isnumber(answer) and question.answers[answer] == true
end

--- Counts the correct answers in a set of answers. A question without an answer counts as
-- answered wrong. Server only.
-- @param answers [Map chosen option position by question ID]
-- @return [Number correct answers, Number questions in the quiz]
function Quiz:grade(answers)
  local correct = 0

  if istable(answers) then
    for k, v in ipairs(self.question_ids) do
      if self:is_answer_correct(v, answers[v]) then
        correct = correct + 1
      end
    end
  end

  return correct, #self.question_ids
end

--- Returns the share of the questions that has to be answered correctly to pass, from the
-- `quiz_pass_percentage` config. Server only.
-- @return [Number percentage from 1 to 100]
function Quiz:get_pass_percentage()
  return math.Clamp(tonumber(Config.get('quiz_pass_percentage', 100)) or 100, 1, 100)
end

--- Returns how long a player who failed has to wait before the next attempt, from the
-- `quiz_retry_delay` config. Server only.
-- @return [Number seconds, 0 when there is no delay]
function Quiz:get_retry_delay()
  return math.max(tonumber(Config.get('quiz_retry_delay', 60)) or 0, 0)
end

--- Checks whether a number of correct answers is enough to pass. Server only.
-- @param correct [Number correct answers]
-- @param total [Number questions in the quiz]
-- @return [Boolean]
function Quiz:is_passing(correct, total)
  return correct * 100 >= total * self:get_pass_percentage()
end

--- Checks whether the quiz is in use: the `quiz_enabled` config is on and at least one
-- question is registered. Server only.
-- @return [Boolean]
function Quiz:is_active()
  return Config.get('quiz_enabled', true) != false and #self.question_ids > 0
end

--- Checks whether a player is exempt from the quiz. Bots always are. Everyone else is asked
-- about through the PlayerCanSkipQuiz hook, and when no handler decides, players with the
-- 'skip_quiz' permission are exempt. Server only.
-- @param target [Player]
-- @return [Boolean]
function Quiz:is_exempt(target)
  if target:IsBot() then return true end

  --- Decides whether a player is exempt from the entry quiz. Called on the server whenever
  -- the plugin has to know whether a player who has not passed must take the quiz: when they
  -- join and on each of their requests to create or load a character, so it has to be cheap.
  -- Not called for bots, who never take the quiz.
  -- @param target [Player the player in question]
  -- @return [Boolean return true to exempt the player, or false to make them take the quiz
  --   even if they have the 'skip_quiz' permission; return nothing to leave the decision to
  --   that permission]
  local exempt = hook.Run('PlayerCanSkipQuiz', target)

  if exempt != nil then
    return exempt == true
  end

  return target:can('skip_quiz') == true
end

--- Checks whether a player has passed the current set of questions. A pass of an earlier set
-- does not count. Server only.
-- @param target [Player]
-- @return [Boolean]
function Quiz:has_passed(target)
  local passed = target:get_player_data('quiz_passed')

  return isstring(passed) and passed == self:get_signature()
end

--- Checks whether a player still has to pass the quiz before they may create or load a
-- character: the quiz is in use, and the player has neither passed it nor is exempt from
-- it. Server only.
-- @param target [Player]
-- @return [Boolean]
-- @see [Quiz:is_active]
-- @see [Quiz:has_passed]
-- @see [Quiz:is_exempt]
function Quiz:is_required(target)
  if !IsValid(target) or !self:is_active() then return false end

  return !self:has_passed(target) and !self:is_exempt(target)
end

--- Returns how long a player who failed the quiz still has to wait before they may try
-- again. The wait never exceeds the `quiz_retry_delay` config, so lowering the config
-- shortens the waits that are already running. Server only.
-- @param target [Player]
-- @return [Number seconds, 0 when the player may try now]
function Quiz:get_retry_wait(target)
  local retry_at = tonumber(target:get_player_data('quiz_retry_at')) or 0

  return math.Clamp(retry_at - os.time(), 0, self:get_retry_delay())
end

--- Records that a player has passed the current set of questions, or forgets that they have.
-- The wait for another attempt is cleared either way, the record of the player is saved at
-- once, and their client is told to show or close the quiz as `Quiz:send` does. Neither
-- PlayerPassedQuiz nor PlayerFailedQuiz runs. Does nothing for bots. Server only.
-- ```
-- -- Make a player take the quiz again.
-- Quiz:set_passed(target, false)
-- ```
-- @param target [Player]
-- @param passed [Boolean]
function Quiz:set_passed(target, passed)
  if !IsValid(target) or target:IsBot() then return end

  local data = target:get_data()

  data.quiz_passed = passed and self:get_signature() or nil
  data.quiz_retry_at = nil

  target:set_data(data)
  target:save_player()

  self:send(target)
end

--- Brings the client of a player up to date: sends the questions, without their answers, to
-- a player who has to take the quiz, which opens the quiz screen in their main menu, and
-- tells any other player to close the screen. Does nothing for bots. Server only.
-- @param target [Player]
-- @return [Boolean true when the quiz was sent, false when the player does not have to take it]
function Quiz:send(target)
  if !IsValid(target) or target:IsBot() then return false end

  if !self:is_required(target) then
    Cable.send(target, 'fl_quiz_close')

    return false
  end

  Cable.send(target, 'fl_quiz_open', self:to_networkable(), {
    signature = self:get_signature(),
    percentage = self:get_pass_percentage(),
    kick = self:kicks_on_fail(),
    delay = self:get_retry_delay(),
    wait = self:get_retry_wait(target)
  })

  return true
end

--- Sends the quiz to a player whose request was refused because they have not passed it,
-- at most once in five seconds. Server only.
-- @param target [Player]
function Quiz:remind(target)
  local cur_time = CurTime()

  if target.next_quiz_reminder and target.next_quiz_reminder > cur_time then return end

  target.next_quiz_reminder = cur_time + 5

  self:send(target)
end

--- Checks whether a player who fails the quiz is kicked, as the `quiz_kick_on_fail` config
-- says. Server only.
-- @return [Boolean]
function Quiz:kicks_on_fail()
  return Config.get('quiz_kick_on_fail', true) != false
end

--- Grades the answers a player has handed in and acts on the result. A player who passes is
-- recorded with `Quiz:set_passed` and the PlayerPassedQuiz hook runs. For a player who fails
-- the PlayerFailedQuiz hook runs, and unless a handler takes over, the player is kicked or,
-- when the `quiz_kick_on_fail` config is off, has to wait for `quiz_retry_delay` seconds
-- before the next attempt. Answers handed in during that wait are not graded. Server only.
-- @param actor [Player the player who handed the answers in]
-- @param answers [Map chosen option position by question ID]
-- @return [Boolean true when the player has passed]
function Quiz:handle_submission(actor, answers)
  if !IsValid(actor) or !istable(answers) then return false end

  if !self:is_required(actor) then
    self:send(actor)

    return false
  end

  local wait = self:get_retry_wait(actor)

  if wait > 0 then
    Cable.send(actor, 'fl_quiz_result', false, wait, false)

    return false
  end

  local correct, total = self:grade(answers)

  if self:is_passing(correct, total) then
    self:set_passed(actor, true)

    Cable.send(actor, 'fl_quiz_result', true, 0, true)

    --- Called on the server when a player has passed the entry quiz, after the pass has been
    -- recorded and saved. Not called for players who are exempt or who are marked as passed
    -- with `Quiz:set_passed`. Do not return anything from the handler, or the plugins after
    -- it are not told.
    -- @param actor [Player the player who has passed]
    -- @param correct [Number how many questions they answered correctly]
    -- @param total [Number how many questions the quiz has]
    hook.Run('PlayerPassedQuiz', actor, correct, total)

    return true
  end

  --- Called on the server when a player has handed in answers that are not enough to pass
  -- the entry quiz, before the plugin punishes them.
  -- @param actor [Player the player who has failed]
  -- @param correct [Number how many questions they answered correctly]
  -- @param total [Number how many questions the quiz has]
  -- @return [Boolean return true to take over: the plugin then neither kicks the player nor
  --   makes them wait, and they may try again at once unless the handler has dealt with
  --   them. Return nothing to let the plugin act as its configs say]
  local handled = hook.Run('PlayerFailedQuiz', actor, correct, total)

  if !IsValid(actor) then return false end

  if handled == true then
    Cable.send(actor, 'fl_quiz_result', false, 0, true)
  elseif self:kicks_on_fail() then
    actor:Kick((t('error.quiz.kicked', nil, Flux.Lang:get_player_lang(actor))))
  else
    local delay = self:get_retry_delay()

    if delay > 0 then
      actor:set_player_data('quiz_retry_at', os.time() + delay)
      actor:save_player()
    end

    Cable.send(actor, 'fl_quiz_result', false, delay, true)
  end

  return false
end
