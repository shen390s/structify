{-# LANGUAGE OverloadedStrings #-}

-- | End-to-end test: Parse → Enrich → Generate
module Main (main) where

import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import System.IO.Temp (withSystemTempDirectory)
import System.FilePath ((</>))

import Structify
import qualified Structify.Parser.C as C

main :: IO ()
main = do
  putStrLn "=== End-to-End Pipeline Test ==="
  putStrLn ""

  -- Test with a simple struct
  withSystemTempDirectory "structify-test" $ \tmpDir -> do
    let headerPath = tmpDir </> "test.h"

    -- Write test header
    let testHeader = T.unlines
          [ "struct Point {"
          , "    int x;"
          , "    int y;"
          , "};"
          ]
    TIO.writeFile headerPath testHeader

    putStrLn "Step 1: Parsing header..."
    parseResult <- parseHeader headerPath
    case parseResult of
      Left err -> do
        putStrLn $ "✗ Parse failed: " ++ show err
        return ()
      Right result -> do
        putStrLn $ "✓ Parsed " ++ show (length $ C.prStructs result) ++ " struct(s)"

        putStrLn "\nStep 2: Enriching structs..."
        case enrichStructs result of
          Left err -> do
            putStrLn $ "✗ Enrichment failed: " ++ show err
            return ()
          Right structs -> do
            putStrLn $ "✓ Enriched " ++ show (length structs) ++ " struct(s)"
            mapM_ printStruct structs

            putStrLn "\nStep 3: Generating code..."
            codeResult <- generateCode headerPath
            case codeResult of
              Left err -> do
                putStrLn $ "✗ Code generation failed: " ++ err
                return ()
              Right (headerCode, sourceCode) -> do
                putStrLn "✓ Code generated successfully"
                putStrLn $ "\nHeader declarations (" ++ show (T.length headerCode) ++ " chars):"
                putStrLn $ T.unpack $ T.take 500 headerCode
                if T.length headerCode > 500 then putStrLn "..." else return ()

                putStrLn $ "\nSource definitions (" ++ show (T.length sourceCode) ++ " chars):"
                putStrLn $ T.unpack $ T.take 500 sourceCode
                if T.length sourceCode > 500 then putStrLn "..." else return ()

  putStrLn "\n=== End-to-End Test Complete ==="

printStruct :: EnrichedStruct -> IO ()
printStruct struct = do
  let StructName name = esName struct
  putStrLn $ "  Struct: " ++ T.unpack name
  putStrLn $ "    Fields: " ++ show (length $ esFields struct)
  mapM_ printField (esFields struct)

printField :: EnrichedField -> IO ()
printField field = do
  let FieldName name = efName field
  putStrLn $ "      - " ++ T.unpack name ++ ": " ++ show (efType field)
