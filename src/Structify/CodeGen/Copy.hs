{-# LANGUAGE OverloadedStrings #-}

-- | Generate copy functions for C structs
--
-- This module generates copy functions that:
-- - Perform deep copies of owned pointers
-- - Handle shallow copies for borrowed pointers
-- - Allocate memory for dynamic arrays
-- - Call custom copy functions
-- - Handle errors with errno-style return codes
module Structify.CodeGen.Copy
  ( -- * Code generation
    generateCopyFunction
  , generateCopyDeclaration

  -- * Types
  , CopyCode(..)
  ) where

import Data.Text (Text)
import qualified Data.Text as T

import Structify.IR.Types

-- | Generated copy code
data CopyCode = CopyCode
  { copyDeclaration :: Text  -- ^ Function declaration for header
  , copyDefinition :: Text   -- ^ Function definition for source
  } deriving (Eq, Show)

-- | Generate copy function declaration for header file
generateCopyDeclaration :: EnrichedStruct -> Text
generateCopyDeclaration struct =
  let StructName name = esName struct
      funcName = T.toLower name <> "_copy"
  in "int " <> funcName <> "(" <> name <> "* dest, const " <> name <> "* src);"

-- | Generate complete copy function
generateCopyFunction :: EnrichedStruct -> CopyCode
generateCopyFunction struct =
  let StructName name = esName struct
      funcName = T.toLower name <> "_copy"
      annots = esAnnotations struct

      -- Check if we should generate copy function
      shouldGenerate = not (saNoCopy annots)

      declaration = generateCopyDeclaration struct
      definition = if shouldGenerate
                   then generateCopyDefinition struct funcName
                   else ""
  in CopyCode
     { copyDeclaration = declaration
     , copyDefinition = definition
     }

-- | Generate copy function definition
generateCopyDefinition :: EnrichedStruct -> Text -> Text
generateCopyDefinition struct funcName =
  let StructName name = esName struct
      annots = esAnnotations struct
      fields = esFields struct

      -- Function signature
      signature = "int " <> funcName <> "(" <> name <> "* dest, const " <> name <> "* src)"

      -- NULL checks
      nullCheck = "    if (dest == NULL || src == NULL) {\n        errno = EINVAL;\n        return -1;\n    }"

      -- Field copies
      fieldCopies = T.unlines $ map (generateFieldCopy name) fields

      -- Success return
      successReturn = "    return 0;"

      -- Error cleanup label (for handling allocation failures)
      errorCleanup = "cleanup:\n    " <> T.toLower name <> "_cleanup(dest);\n    return -1;"

      -- Combine all parts
      parts = filter (not . T.null)
        [ signature <> " {"
        , nullCheck
        , ""
        , "    // Copy fields"
        , fieldCopies
        , successReturn
        , ""
        , errorCleanup
        , "}"
        ]

  in T.unlines parts

-- | Generate copy code for a single field
generateFieldCopy :: Text -> EnrichedField -> Text
generateFieldCopy structName field =
  let FieldName fieldName = efName field
      fieldType = efType field
      annots = efAnnotations field
      destAccessor = "dest->" <> fieldName
      srcAccessor = "src->" <> fieldName

      -- Check if field should not be copied
      skipCopy = faNoCopy annots

  in if skipCopy
     then "    // Skip copying " <> fieldName <> " (no_copy)"
     else generateTypeCopy destAccessor srcAccessor fieldType annots

-- | Generate type-based copy code
generateTypeCopy :: Text -> Text -> EnrichedType -> FieldAnnotations -> Text
generateTypeCopy destAccessor srcAccessor fieldType annots = case fieldType of
  PrimitiveType _ ->
    -- Simple assignment for primitives
    "    " <> destAccessor <> " = " <> srcAccessor <> ";"

  PointerType innerType ownership ->
    let -- For owned pointers, deep copy by default unless explicitly disabled
        deepCopy = case ownership of
          Owned -> not (faNoCopy annots)  -- Deep copy owned pointers by default
          _ -> faDeepCopy annots          -- For borrowed/shared, only if explicitly requested
        allocator = case faAllocator annots of
          Just (FunctionName fn) -> fn
          Nothing -> "malloc"

    in case ownership of
      Owned ->
        if deepCopy
        then
          -- Deep copy: allocate and copy
          case faLengthField annots of
            Just (FieldName lengthField) ->
              -- Array: allocate and copy each element
              case innerType of
                StructType (StructName structName) ->
                  -- Array of structs: deep copy each element
                  "    if (" <> srcAccessor <> " != NULL && src->" <> lengthField <> " > 0) {\n" <>
                  "        " <> destAccessor <> " = " <> allocator <> "(src->" <> lengthField <> " * sizeof(*" <> srcAccessor <> "));\n" <>
                  "        if (" <> destAccessor <> " == NULL) {\n" <>
                  "            errno = ENOMEM;\n" <>
                  "            goto cleanup;\n" <>
                  "        }\n" <>
                  "        for (size_t i = 0; i < src->" <> lengthField <> "; i++) {\n" <>
                  "            if (" <> T.toLower structName <> "_copy(&" <> destAccessor <> "[i], &" <> srcAccessor <> "[i]) != 0) {\n" <>
                  "                goto cleanup;\n" <>
                  "            }\n" <>
                  "        }\n" <>
                  "        dest->" <> lengthField <> " = src->" <> lengthField <> ";\n" <>
                  "    } else {\n" <>
                  "        " <> destAccessor <> " = NULL;\n" <>
                  "        dest->" <> lengthField <> " = 0;\n" <>
                  "    }"

                PointerType (StructType (StructName structName)) _ ->
                  -- Array of struct pointers: allocate array and deep copy each element
                  "    if (" <> srcAccessor <> " != NULL && src->" <> lengthField <> " > 0) {\n" <>
                  "        " <> destAccessor <> " = " <> allocator <> "(src->" <> lengthField <> " * sizeof(*" <> srcAccessor <> "));\n" <>
                  "        if (" <> destAccessor <> " == NULL) {\n" <>
                  "            errno = ENOMEM;\n" <>
                  "            goto cleanup;\n" <>
                  "        }\n" <>
                  "        for (size_t i = 0; i < src->" <> lengthField <> "; i++) {\n" <>
                  "            if (" <> srcAccessor <> "[i] != NULL) {\n" <>
                  "                " <> destAccessor <> "[i] = " <> allocator <> "(sizeof(" <> structName <> "));\n" <>
                  "                if (" <> destAccessor <> "[i] == NULL) {\n" <>
                  "                    errno = ENOMEM;\n" <>
                  "                    goto cleanup;\n" <>
                  "                }\n" <>
                  "                if (" <> T.toLower structName <> "_copy(" <> destAccessor <> "[i], " <> srcAccessor <> "[i]) != 0) {\n" <>
                  "                    goto cleanup;\n" <>
                  "                }\n" <>
                  "            } else {\n" <>
                  "                " <> destAccessor <> "[i] = NULL;\n" <>
                  "            }\n" <>
                  "        }\n" <>
                  "        dest->" <> lengthField <> " = src->" <> lengthField <> ";\n" <>
                  "    } else {\n" <>
                  "        " <> destAccessor <> " = NULL;\n" <>
                  "        dest->" <> lengthField <> " = 0;\n" <>
                  "    }"

                PrimitiveType typeName ->
                  -- Array of primitives: allocate and memcpy
                  "    if (" <> srcAccessor <> " != NULL && src->" <> lengthField <> " > 0) {\n" <>
                  "        " <> destAccessor <> " = " <> allocator <> "(src->" <> lengthField <> " * sizeof(" <> typeName <> "));\n" <>
                  "        if (" <> destAccessor <> " == NULL) {\n" <>
                  "            errno = ENOMEM;\n" <>
                  "            goto cleanup;\n" <>
                  "        }\n" <>
                  "        memcpy(" <> destAccessor <> ", " <> srcAccessor <> ", src->" <> lengthField <> " * sizeof(" <> typeName <> "));\n" <>
                  "        dest->" <> lengthField <> " = src->" <> lengthField <> ";\n" <>
                  "    } else {\n" <>
                  "        " <> destAccessor <> " = NULL;\n" <>
                  "        dest->" <> lengthField <> " = 0;\n" <>
                  "    }"

                _ ->
                  -- Generic array: allocate and memcpy
                  "    if (" <> srcAccessor <> " != NULL && src->" <> lengthField <> " > 0) {\n" <>
                  "        " <> destAccessor <> " = " <> allocator <> "(src->" <> lengthField <> " * sizeof(*" <> srcAccessor <> "));\n" <>
                  "        if (" <> destAccessor <> " == NULL) {\n" <>
                  "            errno = ENOMEM;\n" <>
                  "            goto cleanup;\n" <>
                  "        }\n" <>
                  "        memcpy(" <> destAccessor <> ", " <> srcAccessor <> ", src->" <> lengthField <> " * sizeof(*" <> srcAccessor <> "));\n" <>
                  "        dest->" <> lengthField <> " = src->" <> lengthField <> ";\n" <>
                  "    } else {\n" <>
                  "        " <> destAccessor <> " = NULL;\n" <>
                  "        dest->" <> lengthField <> " = 0;\n" <>
                  "    }"

            Nothing ->
              -- Single pointer: allocate and copy
              case innerType of
                StructType (StructName structName) ->
                  -- Struct pointer: allocate and deep copy
                  "    if (" <> srcAccessor <> " != NULL) {\n" <>
                  "        " <> destAccessor <> " = " <> allocator <> "(sizeof(" <> structName <> "));\n" <>
                  "        if (" <> destAccessor <> " == NULL) {\n" <>
                  "            errno = ENOMEM;\n" <>
                  "            goto cleanup;\n" <>
                  "        }\n" <>
                  "        if (" <> T.toLower structName <> "_copy(" <> destAccessor <> ", " <> srcAccessor <> ") != 0) {\n" <>
                  "            goto cleanup;\n" <>
                  "        }\n" <>
                  "    } else {\n" <>
                  "        " <> destAccessor <> " = NULL;\n" <>
                  "    }"

                PrimitiveType typeName ->
                  -- Special case for char* (strings)
                  if typeName == "char"
                  then
                    "    if (" <> srcAccessor <> " != NULL) {\n" <>
                    "        " <> destAccessor <> " = " <> allocator <> "(strlen(" <> srcAccessor <> ") + 1);\n" <>
                    "        if (" <> destAccessor <> " == NULL) {\n" <>
                    "            errno = ENOMEM;\n" <>
                    "            goto cleanup;\n" <>
                    "        }\n" <>
                    "        strcpy(" <> destAccessor <> ", " <> srcAccessor <> ");\n" <>
                    "    } else {\n" <>
                    "        " <> destAccessor <> " = NULL;\n" <>
                    "    }"
                  else
                    -- Other primitive pointer: allocate and copy value
                    "    if (" <> srcAccessor <> " != NULL) {\n" <>
                    "        " <> destAccessor <> " = " <> allocator <> "(sizeof(" <> typeName <> "));\n" <>
                    "        if (" <> destAccessor <> " == NULL) {\n" <>
                    "            errno = ENOMEM;\n" <>
                    "            goto cleanup;\n" <>
                    "        }\n" <>
                    "        *" <> destAccessor <> " = *" <> srcAccessor <> ";\n" <>
                    "    } else {\n" <>
                    "        " <> destAccessor <> " = NULL;\n" <>
                    "    }"

                _ ->
                  -- Generic pointer: allocate and memcpy
                  "    if (" <> srcAccessor <> " != NULL) {\n" <>
                  "        " <> destAccessor <> " = " <> allocator <> "(sizeof(*" <> srcAccessor <> "));\n" <>
                  "        if (" <> destAccessor <> " == NULL) {\n" <>
                  "            errno = ENOMEM;\n" <>
                  "            goto cleanup;\n" <>
                  "        }\n" <>
                  "        memcpy(" <> destAccessor <> ", " <> srcAccessor <> ", sizeof(*" <> srcAccessor <> "));\n" <>
                  "    } else {\n" <>
                  "        " <> destAccessor <> " = NULL;\n" <>
                  "    }"

        else
          -- Shallow copy: just copy pointer
          "    " <> destAccessor <> " = " <> srcAccessor <> ";"

      Borrowed ->
        -- Borrowed: shallow copy
        "    " <> destAccessor <> " = " <> srcAccessor <> ";"

      Shared ->
        -- Shared: increment reference count (placeholder)
        "    " <> destAccessor <> " = " <> srcAccessor <> ";\n" <>
        "    // TODO: Increment reference count for " <> destAccessor

  ArrayType innerType size ->
    -- Static array: copy element by element
    case innerType of
      StructType (StructName structName) ->
        -- Array of structs: deep copy each element
        let sizeExpr = case size of
              Just n -> T.pack (show n)
              Nothing -> "sizeof(" <> destAccessor <> ") / sizeof(" <> destAccessor <> "[0])"
        in "    for (size_t i = 0; i < " <> sizeExpr <> "; i++) {\n" <>
           "        if (" <> T.toLower structName <> "_copy(&" <> destAccessor <> "[i], &" <> srcAccessor <> "[i]) != 0) {\n" <>
           "            goto cleanup;\n" <>
           "        }\n" <>
           "    }"

      _ ->
        -- Array of primitives: memcpy
        "    memcpy(" <> destAccessor <> ", " <> srcAccessor <> ", sizeof(" <> destAccessor <> "));"

  StructType (StructName structName) ->
    -- Nested struct: call its copy function
    "    if (" <> T.toLower structName <> "_copy(&" <> destAccessor <> ", &" <> srcAccessor <> ") != 0) {\n" <>
    "        goto cleanup;\n" <>
    "    }"

  TypedefType _ ->
    -- Typedef: simple assignment
    "    " <> destAccessor <> " = " <> srcAccessor <> ";"

  FunctionPointerType ->
    -- Function pointer: simple assignment
    "    " <> destAccessor <> " = " <> srcAccessor <> ";"

  UnknownType _ ->
    "    // TODO: Copy " <> destAccessor <> " from " <> srcAccessor
