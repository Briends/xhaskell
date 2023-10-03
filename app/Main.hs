{-# LANGUAGE ExtendedDefaultRules #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Data.Functor.Identity (Identity)
import Lucid

main :: IO ()
main = do
  renderToFile "index.html" $ do
    doctype_
    html_ $ do
      head_ $ do
        title_ "Lucid"
        meta_ [charset_ "utf-8"]
        meta_ [name_ "viewport", content_ "width=device-width, initial-scale=1"]
        link_ [rel_ "stylesheet", type_ "text/css", href_ "style.css"]
        tailwind
        htmx
      body_ [class_ "bg-gray-200"] $ do
        header_ [class_ "text-center py-16 bg-blue-500 text-white"] $
          h1_ [class_ "text-4xl"] "Ask SO"
        main_ [class_ "flex flex-col justify-center mt-10"] $ do
          p_ [class_ "w-full"] "Ask stack overflow all your questions!"
          promptForm

promptForm :: HtmlT Identity ()
promptForm = do
  form_ [class_ "flex flex-col border-gray-300"] $ do
    input_ [class_ "border-2 border-gray-300 p-2 rounded-lg", type_ "text", placeholder_ "Enter your question"]
    button_ [class_ "bg-blue-500 text-white p-2 rounded-lg mt-2", type_ "submit"] "Ask"

tailwind :: HtmlT Identity ()
tailwind = script_ [src_ "https://cdn.tailwindcss.com/3.3.3"] ("" :: String)

htmx :: HtmlT Identity ()
htmx = script_ [src_ "https://unpkg.com/htmx.org@1.9.6", integrity_ "sha384-FhXw7b6AlE/jyjlZH5iHa/tTe9EpJ1Y55RjcgPbjeWMskSxZt1v9qkxLJWNJaGni", crossorigin_ "anonymous"] ("" :: String)