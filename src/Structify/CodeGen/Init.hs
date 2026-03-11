{-# LANGUAGE OverloadedStrings #-}

-- | Generate init functions for C structs
--
-- This module generates initialization functions that:
-- - Set default values for fields
-- - Allocate dynamic memory for owned pointers
-- - Call custom init functions
-- - Call pre/post init hooks
-- - Handle errors with errno-style return codes
module Structify.CodeGen.Init
  ( -- * Code generation
    generateInitFunction
  , generateInitDeclaration

  -- * Types
  , InitCode(..)
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Maybe (isJust, fromMaybe)
import Data.List (intercalate)

import Structify.IR.Types

-- | Generated init code
data InitCode = InitCode
  { icDeclaration :: Text  -- ^ Function declaration for header
  , icDefinition :: Text   -- ^ Function definition for source
  } deriving (Eq, Show)

-- | Generate init function declaration for header file
generateInitDeclaration :: EnrichedStruct -> Text
generateInitDeclaration struct =
  let StructName name = esName struct
      funcName = T.toLower name <> "_init"
  in "int " <> funcName <> "(" <> name <> "* self);"

-- | Generate complete init function
generateInitFunction :: EnrichedStruct -> InitCode
generateInitFunction struct =
  let StructName name = esName struct
      funcName = T.toLower name <> "_init"
      annots = esAnnotations struct

      -- Check if we should generate init function
      shouldGenerate = not (saNoInit annots)

      declaration = generateInitDeclaration struct
      definition = if shouldGenerate
                   then generateInitDefinition struct funcName
                   else ""
  in InitCode
     { icDeclaration = declaration
     , icDefinition = definition
     }

-- | Generate init function definition
generateInitDefinition :: EnrichedStruct -> Text -> Text
generateInitDefinition struct funcName =
  let StructName name = esName struct
      annots = esAnnotations struct
      fields = esFields struct

      -- Function signature
      signature = "int " <> funcName <> "(" <> name <> "* self)"

      -- NULL check
      nullCheck = "    if (self == NULL) {\n        errno = EINVAL;\n        return -1;\n    }"

      -- Pre-init hook
      preInitHook = case saPreInit annots of
        Just (FunctionName fn) ->
          "    // Call pre-init hook\n    if (" <> fn <> "(self) != 0) {\n        return -1;\n    }"
        Nothing -> ""

      -- Field initializations
      fieldInits = T.unlines $ map (generateFieldInit name) fields

      -- Post-init hook
      postInitHook = case saPostInit annots of
        Just (FunctionName fn) ->
          "    // Call post-init hook\n    if (" <> fn <> "(self) != 0) {\n        return -1;\n    }"
        Nothing -> ""

      -- Success return
      successReturn = "    return 0;"

      -- Combine all parts
      parts = filter (not . T.null)
        [ signature <> " {"
        , nullCheck
        , preInitHook
        , ""
        , "    // Initialize fields"
        , fieldInits
        , postInitHook
        , successReturn
        , "}"
        ]

  in T.unlines parts

-- | Generate initialization code for a single field
generateFieldInit :: Text -> EnrichedField -> Text
generateFieldInit structName field =
  let FieldName fieldName = efName field
      fieldType = efType field
      annots = efAnnotations field
      accessor = "self->" <> fieldName

      -- Check for custom init function
      customInit = case faCustomInit annots of
        Just (FunctionName fn) ->
          "    if (" <> fn <> "(&" <> accessor <> ") != 0) {\n        return -1;\n    }"
        Nothing -> generateDefaultInit accessor fieldType annots

  in customInit

-- | Generate default initialization for a field
generateDefaultInit :: Text -> EnrichedType -> FieldAnnotations -> Text
generateDefaultInit accessor fieldType annots =
  case faDefault annots of
    Just defaultVal ->
      "    " <> accessor <> " = " <> defaultVal <> ";"
    Nothing ->
      generateTypeDefaultInit accessor fieldType annots

-- | Generate type-based default initialization
generateTypeDefaultInit :: Text -> EnrichedType -> FieldAnnotations -> Text
generateTypeDefaultInit accessor fieldType annots = case fieldType of
  PrimitiveType typeName ->
    if typeName `elem` ["int", "long", "short", "char", "size_t", "uint8_t", "uint16_t", "uint32_t", "uint64_t"]
    then "    " <> accessor <> " = 0;"
    else if typeName `elem` ["float", "double"]
    then "    " <> accessor <> " = 0.0;"
    else "    " <> accessor <> " = 0;"

  PointerType _ ownership ->
    case ownership of
      Owned -> "    " <> accessor <> " = NULL;"
      Borrowed -> "    " <> accessor <> " = NULL;"
      Shared -> "    " <> accessor <> " = NULL;"

  ArrayType _ _ ->
    -- Arrays are typically initialized to zero
    "    memset(" <> accessor <> ", 0, sizeof(" <> accessor <> "));"

  StructType (StructName structName) ->
    -- Call the struct's init function if it exists
    "    " <> T.toLower structName <> "_init(&" <> accessor <> ");"

  TypedefType _ ->
    "    " <> accessor <> " = 0;"

  FunctionPointerType ->
    "    " <> accessor <> " = NULL;"

  UnknownType _ ->
    "    // TODO: Initialize " <> accessor
