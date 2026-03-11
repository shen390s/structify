-- | CLI entry point for Structify
module Main (main) where

import System.Environment (getArgs)
import System.Exit (exitFailure)

main :: IO ()
main = do
  args <- getArgs
  putStrLn "Structify v0.1.0"
  putStrLn "Usage: structify [COMMAND] [OPTIONS]"
  putStrLn ""
  putStrLn "Commands:"
  putStrLn "  generate    Generate init/cleanup functions (default)"
  putStrLn "  validate    Validate annotations without generating code"
  putStrLn "  analyze     Analyze C header and show annotated structures"
  putStrLn ""
  putStrLn "TODO: Full CLI implementation coming soon"
  putStrLn $ "Args: " ++ show args
  exitFailure
