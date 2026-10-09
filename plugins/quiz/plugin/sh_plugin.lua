--- Quiz makes players pass an entry quiz before they may create or load a character.
-- A question has a text, a list of answer options and the option (or options) that count as
-- correct. The plugin ships no questions: the schema and other plugins register them on the
-- server with `Quiz:add_question`, and while none is registered, or while the `quiz_enabled`
-- config is off, the plugin does nothing.
-- ```
-- -- In a server-side file (sv_ prefix) of the schema or of a plugin that depends on 'quiz'.
-- Quiz:add_question('metagaming', {
--   text = 'my_schema.quiz.metagaming.text',
--   options = {
--     'my_schema.quiz.metagaming.allowed',
--     'my_schema.quiz.metagaming.forbidden'
--   },
--   answer = 2
-- })
--
-- -- A plugin that does not depend on 'quiz' registers from the hook instead.
-- function MyPlugin:RegisterQuizQuestions()
--   Quiz:add_question('powergaming', { text = '...', options = { '...', '...' }, answer = 1 })
-- end
-- ```
-- Questions have to be registered from server-side files. The clients are only ever sent the
-- texts and the options, the answers are graded on the server, and a file that both realms
-- load would hand the correct answers to anyone who reads it.
--
-- A player who has to take the quiz finds it in the main menu in place of the buttons that
-- create and load characters, and the server refuses to create or load a character for them
-- until they have passed. The `quiz_pass_percentage` config sets the share of the questions
-- that has to be answered correctly. A player who fails is kicked when `quiz_kick_on_fail` is
-- on, and otherwise may try again after `quiz_retry_delay` seconds.
--
-- Passing is remembered in the persistent data of the player together with a signature of
-- the questions (their IDs, texts and options), so a player takes the quiz again once the
-- questions have changed. Bots never take it, players with the 'skip_quiz' permission, which
-- assistants and the roles above them have by default, do not either, and the
-- `PlayerCanSkipQuiz` hook decides for everybody else. `PlayerPassedQuiz` and
-- `PlayerFailedQuiz` report the outcome of every attempt.
--
-- The quiz screen is the 'quiz' panel of the theme. Its title and the texts around the
-- questions are the 'ui.quiz' phrases, which a schema replaces by defining them in its own
-- language files.
-- @module [Quiz]

PLUGIN:set_global('Quiz')

require_relative 'sh_enums'
require_relative 'cl_plugin'
require_relative 'cl_hooks'
require_relative 'sv_plugin'
require_relative 'sv_hooks'

--- Registers the 'skip_quiz' permission, which exempts its holders from the quiz.
function Quiz:RegisterPermissions()
  Bolt:register_permission(
    'skip_quiz',
    'Skip the entry quiz',
    'Lets the player create and load characters without passing the entry quiz.',
    'permission.categories.administration',
    'assistant'
  )
end
