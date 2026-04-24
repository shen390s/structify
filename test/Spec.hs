{-# LANGUAGE OverloadedStrings #-}

-- | Test code generation with assertions
module Main (main) where

import Data.Text (Text)
import qualified Data.Text as T
import System.Exit (exitFailure, exitSuccess)

import Structify.IR.Types
import Structify.CodeGen
import Structify.CodeGen.Common (cTypeDefault, cFormatSpecifier, isPrimitiveNumeric, isPrimitiveFloat, structFuncName)

-- ---------------------------------------------------------------------------
-- Test infrastructure
-- ---------------------------------------------------------------------------

data TestResult = Pass String | Fail String String

runTests :: [(String, TestResult)] -> IO ()
runTests results = do
  let failures = [ (name, expected, actual)
                 | (name, Fail expected actual) <- results ]
      passes  = [ name | (name, Pass _) <- results ]

  putStrLn $ "=== Test Results: "
          ++ show (length passes) ++ " passed, "
          ++ show (length failures) ++ " failed ==="
  putStrLn ""

  mapM_ (\name -> putStrLn $ "  PASS: " ++ name) passes

  mapM_ (\(name, expected, actual) -> do
    putStrLn $ "  FAIL: " ++ name
    putStrLn $ "    Expected: " ++ expected
    putStrLn $ "    Actual:   " ++ actual
    ) failures

  if null failures
    then do
      putStrLn "\nAll tests passed."
      exitSuccess
    else do
      putStrLn $ "\n" ++ show (length failures) ++ " test(s) failed."
      exitFailure

assertEqual :: (Eq a, Show a) => String -> a -> a -> (String, TestResult)
assertEqual name expected actual
  | expected == actual = (name, Pass name)
  | otherwise = (name, Fail (show expected) (show actual))

assertContains :: String -> Text -> Text -> (String, TestResult)
assertContains name needle haystack
  | needle `T.isInfixOf` haystack = (name, Pass name)
  | otherwise = (name, Fail
      ("text containing: " ++ T.unpack needle)
      (T.unpack $ T.take 200 haystack))

assertNotEmpty :: String -> Text -> (String, TestResult)
assertNotEmpty name txt
  | not (T.null txt) = (name, Pass name)
  | otherwise = (name, Fail "non-empty text" "empty text")

-- ---------------------------------------------------------------------------
-- Test fixtures
-- ---------------------------------------------------------------------------

-- | A simple struct with basic fields
simpleStruct :: EnrichedStruct
simpleStruct = EnrichedStruct
  { esName = StructName "Point"
  , esFields =
      [ EnrichedField
          { efName = FieldName "x"
          , efType = PrimitiveType "int"
          , efAnnotations = defaultFieldAnnotations
          , efBitField = Nothing
          , efLocation = Nothing
          }
      , EnrichedField
          { efName = FieldName "y"
          , efType = PrimitiveType "int"
          , efAnnotations = defaultFieldAnnotations
          , efBitField = Nothing
          , efLocation = Nothing
          }
      ]
  , esAnnotations = defaultStructAnnotations
  , esLocation = Nothing
  }

-- | A complex struct with pointers, arrays, and nested structs
complexStruct :: EnrichedStruct
complexStruct = EnrichedStruct
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

-- | A struct with generation disabled via annotations
noGenStruct :: EnrichedStruct
noGenStruct = EnrichedStruct
  { esName = StructName "Config"
  , esFields =
      [ EnrichedField
          { efName = FieldName "value"
          , efType = PrimitiveType "int"
          , efAnnotations = defaultFieldAnnotations
          , efBitField = Nothing
          , efLocation = Nothing
          }
      ]
  , esAnnotations = defaultStructAnnotations
      { saNoInit = True
      , saNoCleanup = True
      , saNoCopy = True
      }
  , esLocation = Nothing
  }

-- ---------------------------------------------------------------------------
-- Tests
-- ---------------------------------------------------------------------------

main :: IO ()
main = runTests $ concat
  [ testCommonUtils
  , testSimpleStructCodeGen
  , testComplexStructCodeGen
  , testNoGenAnnotations
  , testGeneratedCodeStructure
  ]

-- | Test CodeGen.Common utility functions
testCommonUtils :: [(String, TestResult)]
testCommonUtils =
  [ assertEqual "cTypeDefault int" "0" (cTypeDefault "int")
  , assertEqual "cTypeDefault float" "0.0" (cTypeDefault "float")
  , assertEqual "cTypeDefault double" "0.0" (cTypeDefault "double")
  , assertEqual "cTypeDefault size_t" "0" (cTypeDefault "size_t")

  , assertEqual "cFormatSpecifier int" "%d" (cFormatSpecifier "int")
  , assertEqual "cFormatSpecifier size_t" "%zu" (cFormatSpecifier "size_t")
  , assertEqual "cFormatSpecifier float" "%f" (cFormatSpecifier "float")
  , assertEqual "cFormatSpecifier double" "%lf" (cFormatSpecifier "double")

  , assertEqual "isPrimitiveNumeric int" True (isPrimitiveNumeric "int")
  , assertEqual "isPrimitiveNumeric char" True (isPrimitiveNumeric "char")
  , assertEqual "isPrimitiveNumeric MyType" False (isPrimitiveNumeric "MyType")

  , assertEqual "isPrimitiveFloat float" True (isPrimitiveFloat "float")
  , assertEqual "isPrimitiveFloat int" False (isPrimitiveFloat "int")

  , assertEqual "structFuncName Person init" "person_init" (structFuncName "Person" "init")
  , assertEqual "structFuncName Buffer cleanup" "buffer_cleanup" (structFuncName "Buffer" "cleanup")
  ]

-- | Test code generation for a simple struct (Point with x, y)
testSimpleStructCodeGen :: [(String, TestResult)]
testSimpleStructCodeGen =
  let code = generateAllFunctions simpleStruct
      header = gcHeaderDeclarations code
      source = gcSourceDefinitions code
  in
  [ assertNotEmpty "simple: header is non-empty" header
  , assertNotEmpty "simple: source is non-empty" source

  -- Init function
  , assertContains "simple: init declaration" "point_init" header
  , assertContains "simple: init signature" "int point_init(Point* self)" source
  , assertContains "simple: init NULL check" "self == NULL" source

  -- Cleanup function
  , assertContains "simple: cleanup declaration" "point_cleanup" header
  , assertContains "simple: cleanup signature" "void point_cleanup(Point* self)" source

  -- Copy function
  , assertContains "simple: copy declaration" "point_copy" header
  , assertContains "simple: copy signature" "Point* dest, const Point* src" source

  -- Print function
  , assertContains "simple: print declaration" "point_print" header
  , assertContains "simple: print signature" "const Point* self, FILE* out" source

  -- Equal functions
  , assertContains "simple: equal declaration" "point_equal" header
  , assertContains "simple: deep_equal declaration" "point_deep_equal" header

  -- Hash function
  , assertContains "simple: hash declaration" "point_hash" header
  , assertContains "simple: hash FNV offset" "14695981039346656037ULL" source
  ]

-- | Test code generation for a complex struct (Person with pointers and arrays)
testComplexStructCodeGen :: [(String, TestResult)]
testComplexStructCodeGen =
  let code = generateAllFunctions complexStruct
      source = gcSourceDefinitions code
  in
  [ -- Init: default values are set
    assertContains "complex: init default name=NULL" "self->name = NULL" source
  , assertContains "complex: init default age=0" "self->age = 0" source
  , assertContains "complex: init default num_children=0" "self->num_children = 0" source

  -- Cleanup: owned pointers are freed
  , assertContains "complex: cleanup frees name" "free(self->name)" source
  , assertContains "complex: cleanup NULLs name" "self->name = NULL" source

  -- Copy: string deep copy
  , assertContains "complex: copy uses strlen for name" "strlen(src->name)" source

  -- Print: string printed with quotes
  , assertContains "complex: print formats string" "self->name" source

  -- Hash: string hashing
  , assertContains "complex: hash handles string" "self->name" source
  ]

-- | Test that no_* annotations suppress generation
testNoGenAnnotations :: [(String, TestResult)]
testNoGenAnnotations =
  let code = generateAllFunctions noGenStruct
      initDef = icDefinition (gcInitCode code)
      cleanupDef = ccDefinition (gcCleanupCode code)
      copyDef = copyDefinition (gcCopyCode code)
  in
  [ assertEqual "noGen: init definition is empty" "" initDef
  , assertEqual "noGen: cleanup definition is empty" "" cleanupDef
  , assertEqual "noGen: copy definition is empty" "" copyDef
  ]

-- | Test overall structure of generated code
testGeneratedCodeStructure :: [(String, TestResult)]
testGeneratedCodeStructure =
  let code = generateAllFunctions simpleStruct
      header = gcHeaderDeclarations code
      source = gcSourceDefinitions code
  in
  [ -- Header should contain section comments
    assertContains "structure: header has init comment" "// Init function" header
  , assertContains "structure: header has cleanup comment" "// Cleanup function" header
  , assertContains "structure: header has copy comment" "// Copy function" header

  -- Source should contain section comments
  , assertContains "structure: source has init comment" "// Init function" source
  , assertContains "structure: source has cleanup comment" "// Cleanup function" source
  ]
