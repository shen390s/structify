-- | Output formatting and messages
module Structify.CLI.Output
  ( printError
  , printSuccess
  , printWarning
  , printInfo
  ) where

import System.IO (hPutStrLn, stderr)

-- | Print an error message
printError :: String -> IO ()
printError msg = hPutStrLn stderr $ "Error: " ++ msg

-- | Print a success message
printSuccess :: String -> IO ()
printSuccess msg = putStrLn $ "✓ " ++ msg

-- | Print a warning message
printWarning :: String -> IO ()
printWarning msg = putStrLn $ "Warning: " ++ msg

-- | Print an info message
printInfo :: String -> IO ()
printInfo msg = putStrLn $ "Info: " ++ msg
