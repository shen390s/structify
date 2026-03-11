{-# LANGUAGE OverloadedStrings #-}

-- | Test C parser with real headers
module Main (main) where

import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO

import Structify.Parser.C

main :: IO ()
main = do
  putStrLn "=== Testing C Parser ==="
  putStrLn ""

  -- Test 1: Parse simple struct
  putStrLn "Test 1: Parsing simple struct..."
  testSimpleStruct

  -- Test 2: Parse struct with attributes
  putStrLn "\nTest 2: Parsing struct with attributes..."
  testStructWithAttributes

  -- Test 3: Parse typedef
  putStrLn "\nTest 3: Parsing typedef..."
  testTypedef

  putStrLn "\n=== All Parser Tests Complete ==="

testSimpleStruct :: IO ()
testSimpleStruct = do
  let code = T.unlines
        [ "struct Point {"
        , "    int x;"
        , "    int y;"
        , "};"
        ]
  case parseHeaderFromString "test.h" code of
    Left err -> putStrLn $ "✗ Parse error: " ++ T.unpack (peMessage err)
    Right result -> do
      putStrLn $ "✓ Parsed " ++ show (length (prStructs result)) ++ " struct(s)"
      case prStructs result of
        [struct] -> do
          putStrLn $ "  Name: " ++ T.unpack (csdName struct)
          putStrLn $ "  Fields: " ++ show (length (csdFields struct))
          mapM_ printField (csdFields struct)
        _ -> putStrLn "✗ Expected 1 struct"

testStructWithAttributes :: IO ()
testStructWithAttributes = do
  let code = T.unlines
        [ "struct Person {"
        , "    char* name __attribute__((annotate(\"structify:owned\")));"
        , "    int age __attribute__((annotate(\"structify:default=0\")));"
        , "};"
        ]
  case parseHeaderFromString "test.h" code of
    Left err -> putStrLn $ "✗ Parse error: " ++ T.unpack (peMessage err)
    Right result -> do
      putStrLn $ "✓ Parsed " ++ show (length (prStructs result)) ++ " struct(s)"
      case prStructs result of
        [struct] -> do
          putStrLn $ "  Name: " ++ T.unpack (csdName struct)
          putStrLn $ "  Fields: " ++ show (length (csdFields struct))
          mapM_ printFieldWithAttrs (csdFields struct)
        _ -> putStrLn "✗ Expected 1 struct"

testTypedef :: IO ()
testTypedef = do
  let code = T.unlines
        [ "typedef struct Point {"
        , "    int x;"
        , "    int y;"
        , "} Point;"
        ]
  case parseHeaderFromString "test.h" code of
    Left err -> putStrLn $ "✗ Parse error: " ++ T.unpack (peMessage err)
    Right result -> do
      putStrLn $ "✓ Parsed " ++ show (length (prTypedefs result)) ++ " typedef(s)"
      putStrLn $ "✓ Parsed " ++ show (length (prStructs result)) ++ " struct(s)"
      mapM_ printTypedef (prTypedefs result)

printField :: CFieldDecl -> IO ()
printField field = do
  putStrLn $ "    - " ++ T.unpack (cfdName field) ++ ": " ++ show (cfdType field)

printFieldWithAttrs :: CFieldDecl -> IO ()
printFieldWithAttrs field = do
  putStrLn $ "    - " ++ T.unpack (cfdName field) ++ ": " ++ show (cfdType field)
  when (not $ null $ cfdAttributes field) $
    putStrLn $ "      Attributes: " ++ show (cfdAttributes field)
  where
    when True action = action
    when False _ = return ()

printTypedef :: (Text, CType) -> IO ()
printTypedef (name, ty) = do
  putStrLn $ "  " ++ T.unpack name ++ " = " ++ show ty
