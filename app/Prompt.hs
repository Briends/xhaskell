{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module Prompt where

import Data.Text (pack)
import Data.UUID (UUID, nil)
import GHC.Generics (Generic)
import Lucid
import Lucid.Htmx
import Servant
import Servant.HTML.Lucid (HTML)
import Text.Printf (printf)
import Web.FormUrlEncoded (FromForm (..))

newtype Prompt = Prompt
  { question :: String
  }
  deriving (Eq, Show, Generic)

data Answer = Answer
  { uuid :: UUID,
    prompt :: Prompt,
    answer :: String
  }
  deriving (Eq, Show, Generic)

type PromptAPI =
  "prompt"
    :> (
         -- POST
         ReqBody '[FormUrlEncoded] Prompt :> Post '[HTML] Answer
           :<|>
           -- GET
           Get '[HTML] Prompt
       )

promptApi :: Proxy PromptAPI
promptApi = Proxy

promptHandler :: Server PromptAPI
promptHandler = postPrompt :<|> getPrompt
  where
    postPrompt :: Prompt -> Handler Answer
    postPrompt prompt = return (Answer {uuid = nil, prompt, answer = "Just start!"})

    getPrompt :: Handler Prompt
    getPrompt = return (Prompt {question = "How do I get started with Haskell?"})

-- Views
------------------

promptView :: (Monad m) => Prompt -> HtmlT m ()
promptView Prompt {..} = do
  h2_ [class_ ""] "Ask stack overflow all your questions!"
  form_
    [ class_ "flex flex-col border-gray-300",
      hxPost_ "/prompt",
      hxPushUrl_ "true"
    ]
    $ do
      input_
        [ class_ "border-2 border-gray-300 p-2 rounded-lg",
          name_ "question",
          type_ "text",
          placeholder_ "Enter your question",
          value_ (pack question)
        ]
      button_
        [ class_ "bg-blue-500 text-white p-2 rounded-lg mt-2",
          type_ "submit"
        ]
        "Ask"

answerView :: (Monad m) => Answer -> HtmlT m ()
answerView Answer {..} = do
  div_ [] $ do
    h2_ "Your prompt was:"
    p_ (toHtml (question prompt))
    h2_ "Your answer is:"
    p_ (toHtml answer)
    hr_ []
    p_
      [class_ "text-sm text-slate-500"]
      (toHtml (printf "uuid: %s" uuidText :: String))
  where
    uuidText = pack $ show uuid

prompt_ :: (Monad m) => HtmlT m ()
prompt_ =
  div_
    [ hxGet_ "/prompt",
      hxTarget_ "this",
      hxSwap_ "outerHTML",
      hxTrigger_ "load"
    ]
    "Loading..."

instance ToHtml Prompt where
  toHtml = promptView
  toHtmlRaw = toHtml

instance ToHtml Answer where
  toHtml = answerView
  toHtmlRaw = toHtml

instance FromForm Prompt