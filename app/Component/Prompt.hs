{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE RecordWildCards #-}

module Component.Prompt
  ( PromptAPI,
    Prompt (..),
    Answer (..),
    promptHandler,
    promptView,
    answerView,
  )
where

import Component.Spinner (spinner)
import Control.Exception (evaluate)
import Control.Monad.IO.Class (liftIO)
import Data.String (IsString)
import Data.Text (pack)
import Data.UUID (UUID, nil)
import GHC.Generics (Generic)
import Lucid
import Lucid.Htmx
import Lucid.Hyperscript (__)
import Servant
import Servant.HTML.Lucid (HTML)
import System.TimeIt (timeItT)
import Text.Printf (printf)
import Web.FormUrlEncoded (FromForm (..))

-- API
------------------

newtype Prompt = Prompt
  { question :: String
  }
  deriving (Eq, Show, Generic, Semigroup, Monoid, IsString)

data Answer = Answer
  { uuid :: UUID,
    prompt :: Prompt,
    answer :: String,
    durationSeconds :: Double
  }
  deriving (Eq, Show, Generic)

{- ORMOLU_DISABLE -}
type PromptAPI =
  "prompt" :> 
  (
    -- POST
    ReqBody '[FormUrlEncoded] Prompt :> Post '[HTML] Answer :<|>
    -- GET
    Get '[HTML] Prompt
  )
{- ORMOLU_ENABLE -}

promptHandler :: Server PromptAPI
promptHandler = postPrompt :<|> getPrompt
  where
    postPrompt :: Prompt -> Handler Answer
    postPrompt prompt = do
      (durationSeconds, result) <-
        liftIO $
          timeItT $
            -- wait for 5 seconds to simulate a long running process
            evaluate (sum [1 .. 100000000] :: Integer)
      -- threadDelay 5000000
      -- print result
      liftIO $ printf "Result: %d\n" result
      return (Answer {uuid = nil, durationSeconds, prompt, answer = "Just start!"})

    getPrompt :: Handler Prompt
    getPrompt = return (Prompt {question = "How do I get started with Haskell?"})

-- Views
------------------

promptView :: (Monad m) => Prompt -> HtmlT m ()
promptView Prompt {..} = do
  form_
    [ id_ "question-form",
      class_ "flex flex-col border-gray-300 space-y-4",
      hxPost_ "/prompt",
      hxPushUrl_ "true",
      hxIndicator_ "#loading-spinner",
      hxExt_ "debug"
    ]
    $ do
      h2_ [class_ "italic"] "Ask stack overflow all your questions!"
      input_
        [ class_ "border-2 border-gray-300 p-2 rounded-lg",
          name_ "question",
          type_ "text",
          placeholder_ "Enter your question",
          value_ (pack question)
        ]
      button_
        [ class_ "flex items-center justify-center bg-blue-500 text-white p-2 rounded-lg mt-2 hover:bg-blue-600 disabled:cursor-not-allowed disabled:bg-gray-600 transition-colors duration-200 ease-in-out",
          type_ "submit",
          [__|
            on htmx:beforeSend from #question-form
              log "¿Sending question?"
              toggle @disabled on me
              toggle .hidden on #button-text
              toggle .hidden on #loading-spinner
          |]
        ]
        $ do
          span_ [id_ "button-text"] "Ask"
          spinner
            [ id_ "loading-spinner",
              class_ "hidden"
            ]

-- class_ "hidden"
-- ]

answerView :: (Monad m) => Answer -> HtmlT m ()
answerView Answer {..} = do
  div_ [class_ "space-y-2"] $ do
    h2_ "Your prompt was:"
    p_ [class_ "italic pl-2"] (toHtml (question prompt))

    h2_ "Your answer is:"
    p_ [class_ "italic pl-2"] (toHtml answer)

    hr_ []

    answerFooter
  where
    uuidText = pack $ show uuid
    answerFooter = do
      span_ [class_ "flex flex-row justify-between"] $ do
        p_
          [class_ "font-mono text-[0.5rem] text-slate-500"]
          (toHtml (printf "uuid: %s" uuidText :: String))
        p_
          [class_ "font-mono text-[0.5rem] text-slate-500"]
          (toHtml (printf "duration: %6.3fs" durationSeconds :: String))

instance ToHtml Prompt where
  toHtml = promptView
  toHtmlRaw = toHtml

instance ToHtml Answer where
  toHtml = answerView
  toHtmlRaw = toHtml

instance FromForm Prompt