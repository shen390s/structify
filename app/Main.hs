-- | CLI entry point for Structify
module Main (main) where

import Structify.CLI.Options (parseOptions, Options(..), optCommand, optVerbose)
import Structify.CLI.Commands (runCommand)

main :: IO ()
main = do
  opts <- parseOptions
  runCommand (optVerbose opts) (optCommand opts)
