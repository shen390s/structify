{-# LANGUAGE OverloadedStrings #-}

-- | Test code generation
module Main (main) where

import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO

import Structify.IR.Types
import Structify.CodeGen

-- | Create a simple test struct
testStruct :: EnrichedStruct
testStruct = EnrichedStruct
  { esName = StructName "Person"
  , esFields =
      [ EnrichedField
          { efName = FieldName "name"
          , efType = PointerType (PrimitiveType "char") Owned
          , efAnnotations = defaultFieldAnnotations
              { faDefault = Just "NULL"
              }
          , efBitField = Nothing
          , efLocation = Nothing
          }
      , EnrichedField
          { efName = FieldName "age"
          , efType = PrimitiveType "int"
          , efAnnotations = defaultFieldAnnotations
              { faDefault = Just "0"
              }
          , efBitField = Nothing
          , efLocation = Nothing
          }
      , EnrichedField
          { efName = FieldName "children"
          , efType = PointerType (PointerType (StructType (StructName "Person")) Owned) Owned
          , efAnnotations = defaultFieldAnnotations
              { faLengthField = Just (FieldName "num_children")
              , faDeepCopy = True
              }
          , efBitField = Nothing
          , efLocation = Nothing
          }
      , EnrichedField
          { efName = FieldName "num_children"
          , efType = PrimitiveType "size_t"
          , efAnnotations = defaultFieldAnnotations
              { faDefault = Just "0"
              }
          , efBitField = Nothing
          , efLocation = Nothing
          }
      ]
  , esAnnotations = defaultStructAnnotations
  , esLocation = Nothing
  }

main :: IO ()
main = do
  putStrLn "=== Testing All Code Generators ==="
  putStrLn ""

  -- Generate all functions at once
  let allCode = generateAllFunctions testStruct

  putStrLn "=== Header Declarations ==="
  TIO.putStrLn (gcHeaderDeclarations allCode)
  putStrLn ""

  putStrLn "=== Source Definitions ==="
  TIO.putStrLn (gcSourceDefinitions allCode)
  putStrLn ""

  putStrLn "=== Test Complete ==="
