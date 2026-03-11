{-# LANGUAGE OverloadedStrings #-}

-- | Generate equality functions for C structs
--
-- This module generates equality functions that:
-- - Compare struct contents for equality
-- - Support both shallow and deep equality
-- - Handle NULL pointers safely
-- - Skip fields marked with no_equal
module Structify.CodeGen.Equal
  ( -- * Code generation
    generateEqualFunction
  , generateDeepEqualFunction
  , generateEqualDeclaration
  , generateDeepEqualDeclaration

  -- * Types
  , EqualCode(..)
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import Data.List (sortBy)
import Data.Ord (comparing)

import Structify.IR.Types

-- | Generated equality code
data EqualCode = EqualCode
  { equalDeclaration :: Text      -- ^ Shallow equality declaration
  , equalDefinition :: Text       -- ^ Shallow equality definition
  , deepEqualDeclaration :: Text  -- ^ Deep equality declaration
  , deepEqualDefinition :: Text   -- ^ Deep equality definition
  } deriving (Eq, Show)

-- | Generate shallow equality function declaration
generateEqualDeclaration :: EnrichedStruct -> Text
generateEqualDeclaration struct =
  let StructName name = esName struct
      funcName = T.toLower name <> "_equal"
  in "bool " <> funcName <> "(const " <> name <> "* a, const " <> name <> "* b);"

-- | Generate deep equality function declaration
generateDeepEqualDeclaration :: EnrichedStruct -> Text
generateDeepEqualDeclaration struct =
  let StructName name = esName struct
      funcName = T.toLower name <> "_deep_equal"
  in "bool " <> funcName <> "(const " <> name <> "* a, const " <> name <> "* b);"

-- | Generate both shallow and deep equality functions
generateEqualFunction :: EnrichedStruct -> EqualCode
generateEqualFunction struct =
  let StructName name = esName struct
      shallowFuncName = T.toLower name <> "_equal"
      deepFuncName = T.toLower name <> "_deep_equal"
      annots = esAnnotations struct

      -- Check if we should generate equality functions
      shouldGenerate = not (saNoEqual annots)

      shallowDecl = generateEqualDeclaration struct
      deepDecl = generateDeepEqualDeclaration struct
      shallowDef = if shouldGenerate
                   then generateEqualDefinition struct shallowFuncName False
                   else ""
      deepDef = if shouldGenerate
                then generateEqualDefinition struct deepFuncName True
                else ""
  in EqualCode
     { equalDeclaration = shallowDecl
     , equalDefinition = shallowDef
     , deepEqualDeclaration = deepDecl
     , deepEqualDefinition = deepDef
     }

-- | Generate deep equality function (convenience wrapper)
generateDeepEqualFunction :: EnrichedStruct -> EqualCode
generateDeepEqualFunction = generateEqualFunction

-- | Generate equality function definition
generateEqualDefinition :: EnrichedStruct -> Text -> Bool -> Text
generateEqualDefinition struct funcName isDeep =
  let StructName name = esName struct
      fields = esFields struct

      -- Collect all length field names (these will be checked inline with their arrays)
      lengthFields = [ lengthField
                     | field <- fields
                     , Just lengthField <- [faLengthField (efAnnotations field)]
                     ]

      -- Sort fields by comparison cost for better performance:
      -- 1. Primitives (fastest - simple integer/float comparison)
      -- 2. Pointers (slower - may need strcmp or array iteration)
      -- 3. Nested structs (slowest - recursive calls)
      sortedFields = sortFieldsByComparisonCost fields

      -- Function signature
      signature = "bool " <> funcName <> "(const " <> name <> "* a, const " <> name <> "* b)"

      -- NULL checks
      nullCheck = "    // Handle NULL pointers\n" <>
                  "    if (a == b) return true;  // Same pointer or both NULL\n" <>
                  "    if (a == NULL || b == NULL) return false;  // One is NULL"

      -- Field comparisons (skip length fields as they're checked inline with arrays)
      fieldComparisons = T.unlines $ map (generateFieldEqual name isDeep lengthFields) sortedFields

      -- Success return
      successReturn = "    return true;"

      -- Combine all parts
      parts = filter (not . T.null)
        [ signature <> " {"
        , nullCheck
        , ""
        , "    // Compare fields (primitives first for early exit)"
        , fieldComparisons
        , successReturn
        , "}"
        ]

  in T.unlines parts

-- | Sort fields by comparison cost (cheapest first)
sortFieldsByComparisonCost :: [EnrichedField] -> [EnrichedField]
sortFieldsByComparisonCost = sortBy compareFieldCost
  where
    compareFieldCost f1 f2 = compare (fieldCost f1) (fieldCost f2)

    fieldCost :: EnrichedField -> Int
    fieldCost field = case efType field of
      PrimitiveType _ -> 1  -- Cheapest: simple comparison
      PointerType (PrimitiveType "char") _ -> 3  -- String: strcmp
      PointerType _ _ -> 4  -- Pointer: may need deep comparison
      ArrayType _ _ -> 5  -- Array: iteration
      StructType _ -> 6  -- Nested struct: recursive call
      TypedefType _ -> 2  -- Typedef: usually primitive
      FunctionPointerType -> 2  -- Function pointer: simple comparison
      UnknownType _ -> 7  -- Unknown: assume expensive

-- | Generate equality check for a single field
generateFieldEqual :: Text -> Bool -> [FieldName] -> EnrichedField -> Text
generateFieldEqual structName isDeep lengthFields field =
  let FieldName fieldName = efName field
      fieldType = efType field
      annots = efAnnotations field
      accessorA = "a->" <> fieldName
      accessorB = "b->" <> fieldName

      -- Check if field should not be compared
      skipEqual = faNoEqual annots

      -- Check if this field is a length field (already checked inline with array)
      isLengthField = efName field `elem` lengthFields

  in if skipEqual || isLengthField
     then ""
     else generateTypeEqual accessorA accessorB fieldType annots isDeep

-- | Generate type-based equality check
generateTypeEqual :: Text -> Text -> EnrichedType -> FieldAnnotations -> Bool -> Text
generateTypeEqual accessorA accessorB fieldType annots isDeep = case fieldType of
  PrimitiveType _ ->
    -- Simple comparison for primitives
    "    if (" <> accessorA <> " != " <> accessorB <> ") return false;\n"

  PointerType innerType ownership ->
    case innerType of
      PrimitiveType "char" ->
        if isDeep
        then
          -- Deep string comparison
          "    if (" <> accessorA <> " != " <> accessorB <> ") {\n" <>
          "        if (" <> accessorA <> " == NULL || " <> accessorB <> " == NULL) return false;\n" <>
          "        if (strcmp(" <> accessorA <> ", " <> accessorB <> ") != 0) return false;\n" <>
          "    }\n"
        else
          -- Shallow pointer comparison
          "    if (" <> accessorA <> " != " <> accessorB <> ") return false;\n"

      StructType (StructName structName) ->
        if isDeep
        then
          -- Deep struct comparison
          case faLengthField annots of
            Just (FieldName lengthField) ->
              -- Array of struct pointers: check length first, then compare elements
              "    // Check length field first\n" <>
              "    if (a->" <> lengthField <> " != b->" <> lengthField <> ") return false;\n" <>
              "    // Compare array contents\n" <>
              "    if (" <> accessorA <> " != " <> accessorB <> ") {\n" <>
              "        if (" <> accessorA <> " == NULL || " <> accessorB <> " == NULL) return false;\n" <>
              "        for (size_t i = 0; i < a->" <> lengthField <> "; i++) {\n" <>
              "            if (!" <> T.toLower structName <> "_deep_equal(" <> accessorA <> "[i], " <> accessorB <> "[i])) return false;\n" <>
              "        }\n" <>
              "    }\n"
            Nothing ->
              -- Single struct pointer
              "    if (" <> accessorA <> " != " <> accessorB <> ") {\n" <>
              "        if (" <> accessorA <> " == NULL || " <> accessorB <> " == NULL) return false;\n" <>
              "        if (!" <> T.toLower structName <> "_deep_equal(" <> accessorA <> ", " <> accessorB <> ")) return false;\n" <>
              "    }\n"
        else
          -- Shallow pointer comparison
          "    if (" <> accessorA <> " != " <> accessorB <> ") return false;\n"

      PointerType (StructType (StructName structName)) _ ->
        -- Pointer to struct pointer (e.g., Person**)
        if isDeep
        then
          case faLengthField annots of
            Just (FieldName lengthField) ->
              -- Array of struct pointers: check length first, then deep compare each
              "    // Check length field first\n" <>
              "    if (a->" <> lengthField <> " != b->" <> lengthField <> ") return false;\n" <>
              "    // Compare array contents\n" <>
              "    if (" <> accessorA <> " != " <> accessorB <> ") {\n" <>
              "        if (" <> accessorA <> " == NULL || " <> accessorB <> " == NULL) return false;\n" <>
              "        for (size_t i = 0; i < a->" <> lengthField <> "; i++) {\n" <>
              "            if (!" <> T.toLower structName <> "_deep_equal(" <> accessorA <> "[i], " <> accessorB <> "[i])) return false;\n" <>
              "        }\n" <>
              "    }\n"
            Nothing ->
              -- Single pointer to struct pointer
              "    if (" <> accessorA <> " != " <> accessorB <> ") {\n" <>
              "        if (" <> accessorA <> " == NULL || " <> accessorB <> " == NULL) return false;\n" <>
              "        if (!" <> T.toLower structName <> "_deep_equal(*" <> accessorA <> ", *" <> accessorB <> ")) return false;\n" <>
              "    }\n"
        else
          -- Shallow pointer comparison
          "    if (" <> accessorA <> " != " <> accessorB <> ") return false;\n"

      _ ->
        if isDeep
        then
          -- Deep comparison for other pointers
          case faLengthField annots of
            Just (FieldName lengthField) ->
              -- Array: check length first, then compare contents
              "    // Check length field first\n" <>
              "    if (a->" <> lengthField <> " != b->" <> lengthField <> ") return false;\n" <>
              "    // Compare array contents\n" <>
              "    if (" <> accessorA <> " != " <> accessorB <> ") {\n" <>
              "        if (" <> accessorA <> " == NULL || " <> accessorB <> " == NULL) return false;\n" <>
              "        if (memcmp(" <> accessorA <> ", " <> accessorB <> ", a->" <> lengthField <> " * sizeof(*" <> accessorA <> ")) != 0) return false;\n" <>
              "    }\n"
            Nothing ->
              -- Single value: dereference and compare
              "    if (" <> accessorA <> " != " <> accessorB <> ") {\n" <>
              "        if (" <> accessorA <> " == NULL || " <> accessorB <> " == NULL) return false;\n" <>
              "        if (*" <> accessorA <> " != *" <> accessorB <> ") return false;\n" <>
              "    }\n"
        else
          -- Shallow pointer comparison
          "    if (" <> accessorA <> " != " <> accessorB <> ") return false;\n"

  ArrayType innerType size ->
    case innerType of
      StructType (StructName structName) ->
        if isDeep
        then
          -- Deep array comparison
          let sizeExpr = case size of
                Just n -> T.pack (show n)
                Nothing -> "sizeof(" <> accessorA <> ") / sizeof(" <> accessorA <> "[0])"
          in "    for (size_t i = 0; i < " <> sizeExpr <> "; i++) {\n" <>
             "        if (!" <> T.toLower structName <> "_deep_equal(&" <> accessorA <> "[i], &" <> accessorB <> "[i])) return false;\n" <>
             "    }\n"
        else
          -- Shallow array comparison (memcmp)
          "    if (memcmp(" <> accessorA <> ", " <> accessorB <> ", sizeof(" <> accessorA <> ")) != 0) return false;\n"

      _ ->
        -- Array of primitives: memcmp
        "    if (memcmp(" <> accessorA <> ", " <> accessorB <> ", sizeof(" <> accessorA <> ")) != 0) return false;\n"

  StructType (StructName structName) ->
    if isDeep
    then
      -- Deep nested struct comparison
      "    if (!" <> T.toLower structName <> "_deep_equal(&" <> accessorA <> ", &" <> accessorB <> ")) return false;\n"
    else
      -- Shallow nested struct comparison
      "    if (!" <> T.toLower structName <> "_equal(&" <> accessorA <> ", &" <> accessorB <> ")) return false;\n"

  TypedefType _ ->
    -- Typedef: simple comparison
    "    if (" <> accessorA <> " != " <> accessorB <> ") return false;\n"

  FunctionPointerType ->
    -- Function pointer: pointer comparison
    "    if (" <> accessorA <> " != " <> accessorB <> ") return false;\n"

  UnknownType _ ->
    "    // TODO: Compare " <> accessorA <> " with " <> accessorB <> "\n"
