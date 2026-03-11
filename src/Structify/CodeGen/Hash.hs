{-# LANGUAGE OverloadedStrings #-}

-- | Generate hash functions for C structs
--
-- This module generates hash functions that:
-- - Compute FNV-1a hash of struct contents
-- - Handle NULL pointers safely
-- - Skip fields marked with no_hash
-- - Support custom hash functions
module Structify.CodeGen.Hash
  ( -- * Code generation
    generateHashFunction
  , generateHashDeclaration

  -- * Types
  , HashCode(..)
  ) where

import Data.Text (Text)
import qualified Data.Text as T

import Structify.IR.Types

-- | Generated hash code
data HashCode = HashCode
  { hashDeclaration :: Text  -- ^ Function declaration for header
  , hashDefinition :: Text   -- ^ Function definition for source
  } deriving (Eq, Show)

-- | Generate hash function declaration for header file
generateHashDeclaration :: EnrichedStruct -> Text
generateHashDeclaration struct =
  let StructName name = esName struct
      funcName = T.toLower name <> "_hash"
  in "uint64_t " <> funcName <> "(const " <> name <> "* self);"

-- | Generate complete hash function
generateHashFunction :: EnrichedStruct -> HashCode
generateHashFunction struct =
  let StructName name = esName struct
      funcName = T.toLower name <> "_hash"
      annots = esAnnotations struct

      -- Check if we should generate hash function
      shouldGenerate = not (saNoHash annots)

      declaration = generateHashDeclaration struct
      definition = if shouldGenerate
                   then generateHashDefinition struct funcName
                   else ""
  in HashCode
     { hashDeclaration = declaration
     , hashDefinition = definition
     }

-- | Generate hash function definition
generateHashDefinition :: EnrichedStruct -> Text -> Text
generateHashDefinition struct funcName =
  let StructName name = esName struct
      fields = esFields struct

      -- Function signature
      signature = "uint64_t " <> funcName <> "(const " <> name <> "* self)"

      -- NULL check
      nullCheck = "    if (self == NULL) return 0;"

      -- FNV-1a constants
      fnvInit = "    // FNV-1a hash (64-bit)\n" <>
                "    uint64_t hash = 14695981039346656037ULL;  // FNV offset basis\n" <>
                "    const uint64_t fnv_prime = 1099511628211ULL;"

      -- Field hashes
      fieldHashes = T.unlines $ map generateFieldHash fields

      -- Return hash
      returnHash = "    return hash;"

      -- Combine all parts
      parts = filter (not . T.null)
        [ signature <> " {"
        , nullCheck
        , ""
        , fnvInit
        , ""
        , "    // Hash fields"
        , fieldHashes
        , returnHash
        , "}"
        ]

  in T.unlines parts

-- | Generate hash code for a single field
generateFieldHash :: EnrichedField -> Text
generateFieldHash field =
  let FieldName fieldName = efName field
      fieldType = efType field
      annots = efAnnotations field
      accessor = "self->" <> fieldName

      -- Check if field should not be hashed
      skipHash = faNoHash annots

  in if skipHash
     then ""
     else
       case faCustomHash annots of
         Just (FunctionName customFunc) ->
           -- Use custom hash function
           "    hash ^= " <> customFunc <> "(&" <> accessor <> ");\n" <>
           "    hash *= fnv_prime;\n"
         Nothing ->
           generateTypeHash accessor fieldType annots

-- | Generate type-based hash code
generateTypeHash :: Text -> EnrichedType -> FieldAnnotations -> Text
generateTypeHash accessor fieldType annots = case fieldType of
  PrimitiveType typeName ->
    -- Hash primitive by mixing in bytes
    case typeName of
      "char" ->
        "    hash ^= (uint64_t)" <> accessor <> ";\n" <>
        "    hash *= fnv_prime;\n"
      _ ->
        "    {\n" <>
        "        const uint8_t* bytes = (const uint8_t*)&" <> accessor <> ";\n" <>
        "        for (size_t i = 0; i < sizeof(" <> accessor <> "); i++) {\n" <>
        "            hash ^= bytes[i];\n" <>
        "            hash *= fnv_prime;\n" <>
        "        }\n" <>
        "    }\n"

  PointerType innerType _ ->
    case innerType of
      PrimitiveType "char" ->
        -- Hash string contents
        "    if (" <> accessor <> " != NULL) {\n" <>
        "        const char* str = " <> accessor <> ";\n" <>
        "        while (*str) {\n" <>
        "            hash ^= (uint64_t)*str++;\n" <>
        "            hash *= fnv_prime;\n" <>
        "        }\n" <>
        "    }\n"

      StructType (StructName structName) ->
        case faLengthField annots of
          Just (FieldName lengthField) ->
            -- Array of struct pointers: hash each element
            "    if (" <> accessor <> " != NULL) {\n" <>
            "        for (size_t i = 0; i < self->" <> lengthField <> "; i++) {\n" <>
            "            if (" <> accessor <> "[i] != NULL) {\n" <>
            "                hash ^= " <> T.toLower structName <> "_hash(" <> accessor <> "[i]);\n" <>
            "                hash *= fnv_prime;\n" <>
            "            }\n" <>
            "        }\n" <>
            "    }\n"
          Nothing ->
            -- Single struct pointer: hash the struct
            "    if (" <> accessor <> " != NULL) {\n" <>
            "        hash ^= " <> T.toLower structName <> "_hash(" <> accessor <> ");\n" <>
            "        hash *= fnv_prime;\n" <>
            "    }\n"

      _ ->
        case faLengthField annots of
          Just (FieldName lengthField) ->
            -- Array: hash each byte
            "    if (" <> accessor <> " != NULL) {\n" <>
            "        const uint8_t* bytes = (const uint8_t*)" <> accessor <> ";\n" <>
            "        for (size_t i = 0; i < self->" <> lengthField <> " * sizeof(*" <> accessor <> "); i++) {\n" <>
            "            hash ^= bytes[i];\n" <>
            "            hash *= fnv_prime;\n" <>
            "        }\n" <>
            "    }\n"
          Nothing ->
            -- Single pointer: hash the value
            "    if (" <> accessor <> " != NULL) {\n" <>
            "        const uint8_t* bytes = (const uint8_t*)" <> accessor <> ";\n" <>
            "        for (size_t i = 0; i < sizeof(*" <> accessor <> "); i++) {\n" <>
            "            hash ^= bytes[i];\n" <>
            "            hash *= fnv_prime;\n" <>
            "        }\n" <>
            "    }\n"

  ArrayType innerType size ->
    case innerType of
      StructType (StructName structName) ->
        -- Array of structs: hash each element
        let sizeExpr = case size of
              Just n -> T.pack (show n)
              Nothing -> "sizeof(" <> accessor <> ") / sizeof(" <> accessor <> "[0])"
        in "    for (size_t i = 0; i < " <> sizeExpr <> "; i++) {\n" <>
           "        hash ^= " <> T.toLower structName <> "_hash(&" <> accessor <> "[i]);\n" <>
           "        hash *= fnv_prime;\n" <>
           "    }\n"

      _ ->
        -- Array of primitives: hash all bytes
        "    {\n" <>
        "        const uint8_t* bytes = (const uint8_t*)" <> accessor <> ";\n" <>
        "        for (size_t i = 0; i < sizeof(" <> accessor <> "); i++) {\n" <>
        "            hash ^= bytes[i];\n" <>
        "            hash *= fnv_prime;\n" <>
        "        }\n" <>
        "    }\n"

  StructType (StructName structName) ->
    -- Nested struct: hash the struct
    "    hash ^= " <> T.toLower structName <> "_hash(&" <> accessor <> ");\n" <>
    "    hash *= fnv_prime;\n"

  TypedefType _ ->
    -- Typedef: hash as bytes
    "    {\n" <>
    "        const uint8_t* bytes = (const uint8_t*)&" <> accessor <> ";\n" <>
    "        for (size_t i = 0; i < sizeof(" <> accessor <> "); i++) {\n" <>
    "            hash ^= bytes[i];\n" <>
    "            hash *= fnv_prime;\n" <>
    "        }\n" <>
    "    }\n"

  FunctionPointerType ->
    -- Function pointer: hash the pointer value
    "    {\n" <>
    "        const uint8_t* bytes = (const uint8_t*)&" <> accessor <> ";\n" <>
    "        for (size_t i = 0; i < sizeof(" <> accessor <> "); i++) {\n" <>
    "            hash ^= bytes[i];\n" <>
    "            hash *= fnv_prime;\n" <>
    "        }\n" <>
    "    }\n"

  UnknownType _ ->
    "    // TODO: Hash " <> accessor <> "\n"
