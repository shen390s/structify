{-# LANGUAGE OverloadedStrings #-}

-- | Generate cleanup functions for C structs
--
-- This module generates cleanup functions that:
-- - Free owned pointers and dynamic memory
-- - Call custom cleanup functions
-- - Handle arrays using length fields
-- - Call pre/post cleanup hooks
-- - Provide NULL safety
module Structify.CodeGen.Cleanup
  ( -- * Code generation
    generateCleanupFunction
  , generateCleanupDeclaration

  -- * Types
  , CleanupCode(..)
  ) where

import Data.Text (Text)
import qualified Data.Text as T

import Structify.IR.Types
import Structify.CodeGen.Common (cNullCheckVoid, structFuncName, assembleFunction)

-- | Generated cleanup code
data CleanupCode = CleanupCode
  { ccDeclaration :: Text  -- ^ Function declaration for header
  , ccDefinition :: Text   -- ^ Function definition for source
  } deriving (Eq, Show)

-- | Generate cleanup function declaration for header file
generateCleanupDeclaration :: EnrichedStruct -> Text
generateCleanupDeclaration struct =
  let StructName name = esName struct
      funcName = T.toLower name <> "_cleanup"
  in "void " <> funcName <> "(" <> name <> "* self);"

-- | Generate complete cleanup function
generateCleanupFunction :: EnrichedStruct -> CleanupCode
generateCleanupFunction struct =
  let StructName name = esName struct
      funcName = T.toLower name <> "_cleanup"
      annots = esAnnotations struct

      -- Check if we should generate cleanup function
      shouldGenerate = not (saNoCleanup annots)

      declaration = generateCleanupDeclaration struct
      definition = if shouldGenerate
                   then generateCleanupDefinition struct funcName
                   else ""
  in CleanupCode
     { ccDeclaration = declaration
     , ccDefinition = definition
     }

-- | Generate cleanup function definition
generateCleanupDefinition :: EnrichedStruct -> Text -> Text
generateCleanupDefinition struct funcName =
  let StructName name = esName struct
      annots = esAnnotations struct
      fields = esFields struct

      -- Function signature
      signature = "void " <> funcName <> "(" <> name <> "* self)"

      -- NULL check
      nullCheck = "    if (self == NULL) {\n        return;\n    }"

      -- Pre-cleanup hook
      preCleanupHook = case saPreCleanup annots of
        Just (FunctionName fn) ->
          "    // Call pre-cleanup hook\n    " <> fn <> "(self);"
        Nothing -> ""

      -- Field cleanups (in reverse order for proper cleanup)
      fieldCleanups = T.unlines $ map (generateFieldCleanup name) (reverse fields)

      -- Post-cleanup hook
      postCleanupHook = case saPostCleanup annots of
        Just (FunctionName fn) ->
          "    // Call post-cleanup hook\n    " <> fn <> "(self);"
        Nothing -> ""

      -- Combine all parts
      parts = filter (not . T.null)
        [ signature <> " {"
        , nullCheck
        , preCleanupHook
        , ""
        , "    // Cleanup fields"
        , fieldCleanups
        , postCleanupHook
        , "}"
        ]

  in T.unlines parts

-- | Generate cleanup code for a single field
generateFieldCleanup :: Text -> EnrichedField -> Text
generateFieldCleanup structName field =
  let FieldName fieldName = efName field
      fieldType = efType field
      annots = efAnnotations field
      accessor = "self->" <> fieldName

      -- Check for custom cleanup function
      customCleanup = case faCustomCleanup annots of
        Just (FunctionName fn) ->
          "    " <> fn <> "(&" <> accessor <> ");"
        Nothing -> generateDefaultCleanup accessor fieldType annots

  in customCleanup

-- | Generate default cleanup for a field
generateDefaultCleanup :: Text -> EnrichedType -> FieldAnnotations -> Text
generateDefaultCleanup accessor fieldType annots =
  generateTypeDefaultCleanup accessor fieldType annots

-- | Generate type-based default cleanup
generateTypeDefaultCleanup :: Text -> EnrichedType -> FieldAnnotations -> Text
generateTypeDefaultCleanup accessor fieldType annots = case fieldType of
  PrimitiveType _ ->
    -- Primitives don't need cleanup
    ""

  PointerType innerType ownership ->
    case ownership of
      Owned ->
        -- Free owned pointers
        let deallocator = case faDeallocator annots of
              Just (FunctionName fn) -> fn
              Nothing -> "free"

            -- Check if this is an array with length field
            cleanupCode = case faLengthField annots of
              Just (FieldName lengthField) ->
                -- Array: cleanup each element if needed, then free array
                case innerType of
                  StructType (StructName structName) ->
                    -- Array of structs: cleanup each element
                    "    if (" <> accessor <> " != NULL) {\n" <>
                    "        for (size_t i = 0; i < self->" <> lengthField <> "; i++) {\n" <>
                    "            " <> T.toLower structName <> "_cleanup(&" <> accessor <> "[i]);\n" <>
                    "        }\n" <>
                    "        " <> deallocator <> "(" <> accessor <> ");\n" <>
                    "        " <> accessor <> " = NULL;\n" <>
                    "    }"

                  PointerType (StructType (StructName structName)) _ ->
                    -- Array of struct pointers: cleanup and free each element
                    "    if (" <> accessor <> " != NULL) {\n" <>
                    "        for (size_t i = 0; i < self->" <> lengthField <> "; i++) {\n" <>
                    "            if (" <> accessor <> "[i] != NULL) {\n" <>
                    "                " <> T.toLower structName <> "_cleanup(" <> accessor <> "[i]);\n" <>
                    "                " <> deallocator <> "(" <> accessor <> "[i]);\n" <>
                    "            }\n" <>
                    "        }\n" <>
                    "        " <> deallocator <> "(" <> accessor <> ");\n" <>
                    "        " <> accessor <> " = NULL;\n" <>
                    "    }"

                  _ ->
                    -- Array of primitives or other types: just free
                    "    if (" <> accessor <> " != NULL) {\n" <>
                    "        " <> deallocator <> "(" <> accessor <> ");\n" <>
                    "        " <> accessor <> " = NULL;\n" <>
                    "    }"

              Nothing ->
                -- Single pointer
                case innerType of
                  StructType (StructName structName) ->
                    -- Struct pointer: cleanup then free
                    "    if (" <> accessor <> " != NULL) {\n" <>
                    "        " <> T.toLower structName <> "_cleanup(" <> accessor <> ");\n" <>
                    "        " <> deallocator <> "(" <> accessor <> ");\n" <>
                    "        " <> accessor <> " = NULL;\n" <>
                    "    }"

                  _ ->
                    -- Other pointer: just free
                    "    if (" <> accessor <> " != NULL) {\n" <>
                    "        " <> deallocator <> "(" <> accessor <> ");\n" <>
                    "        " <> accessor <> " = NULL;\n" <>
                    "    }"

        in cleanupCode

      Borrowed ->
        -- Borrowed pointers: just set to NULL
        "    " <> accessor <> " = NULL;"

      Shared ->
        -- Shared pointers: decrement reference count (placeholder)
        "    // TODO: Decrement reference count for " <> accessor

  ArrayType innerType _ ->
    -- Static arrays: cleanup elements if needed
    case innerType of
      StructType (StructName structName) ->
        -- Array of structs: cleanup each element
        "    for (size_t i = 0; i < sizeof(" <> accessor <> ") / sizeof(" <> accessor <> "[0]); i++) {\n" <>
        "        " <> T.toLower structName <> "_cleanup(&" <> accessor <> "[i]);\n" <>
        "    }"
      _ ->
        -- Array of primitives: no cleanup needed
        ""

  StructType (StructName structName) ->
    -- Nested struct: call its cleanup function
    "    " <> T.toLower structName <> "_cleanup(&" <> accessor <> ");"

  TypedefType _ ->
    -- Typedefs: no cleanup needed (unless it's a pointer, handled above)
    ""

  FunctionPointerType ->
    -- Function pointers: just set to NULL
    "    " <> accessor <> " = NULL;"

  UnknownType _ ->
    "    // TODO: Cleanup " <> accessor
