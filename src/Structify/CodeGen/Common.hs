{-# LANGUAGE OverloadedStrings #-}

-- | Shared utilities for code generation
--
-- This module provides common helpers used across all code generators
-- (Init, Cleanup, Copy, Print, Equal, Hash) to reduce duplication and
-- ensure consistent C code output.
module Structify.CodeGen.Common
  ( -- * C code building helpers
    cBlock
  , cIf
  , cIfNull
  , cIfNotNull
  , cForLoop
  , cNullCheck
  , cNullCheckReturn
  , cNullCheckVoid
  , cIndent

    -- * Type utilities
  , cTypeDefault
  , cFormatSpecifier
  , isPrimitiveNumeric
  , isPrimitiveFloat
  , structFuncName

    -- * Code assembly
  , assembleFunction
  , filterEmpty
  ) where

import Data.Text (Text)
import qualified Data.Text as T

import Structify.IR.Types

-- ---------------------------------------------------------------------------
-- C code building helpers
-- ---------------------------------------------------------------------------

-- | Wrap lines in a C block: @{ ... }@
cBlock :: Text -> [Text] -> Text
cBlock header bodyLines =
  T.unlines $ [header <> " {"] ++ bodyLines ++ ["}"]

-- | Generate a simple @if (cond) { body }@ statement
cIf :: Text -> [Text] -> Text
cIf condition bodyLines =
  T.unlines $
    ["    if (" <> condition <> ") {"]
    ++ map ("    " <>) bodyLines
    ++ ["    }"]

-- | Generate @if (ptr == NULL) { body }@
cIfNull :: Text -> [Text] -> Text
cIfNull ptr = cIf (ptr <> " == NULL")

-- | Generate @if (ptr != NULL) { body }@ with an optional else branch
cIfNotNull :: Text -> [Text] -> [Text] -> Text
cIfNotNull ptr thenLines elseLines =
  let thenPart = ["    if (" <> ptr <> " != NULL) {"]
                 ++ map ("    " <>) thenLines
      elsePart = if null elseLines
                 then ["    }"]
                 else ["    } else {"]
                      ++ map ("    " <>) elseLines
                      ++ ["    }"]
  in T.unlines $ thenPart ++ elsePart

-- | Generate a @for@ loop over an index variable
cForLoop :: Text -> Text -> [Text] -> Text
cForLoop indexVar bound bodyLines =
  T.unlines $
    ["    for (size_t " <> indexVar <> " = 0; " <> indexVar <> " < " <> bound <> "; " <> indexVar <> "++) {"]
    ++ map ("    " <>) bodyLines
    ++ ["    }"]

-- | Generate a NULL check that returns -1 and sets errno (for init/copy style functions)
cNullCheck :: Text -> Text
cNullCheck param =
  "    if (" <> param <> " == NULL) {\n" <>
  "        errno = EINVAL;\n" <>
  "        return -1;\n" <>
  "    }"

-- | Generate a NULL check that returns a specific value
cNullCheckReturn :: Text -> Text -> Text
cNullCheckReturn param retVal =
  "    if (" <> param <> " == NULL) {\n" <>
  "        return " <> retVal <> ";\n" <>
  "    }"

-- | Generate a NULL check that returns void
cNullCheckVoid :: Text -> Text
cNullCheckVoid param =
  "    if (" <> param <> " == NULL) {\n" <>
  "        return;\n" <>
  "    }"

-- | Indent a text block by n levels (4 spaces each)
cIndent :: Int -> Text -> Text
cIndent n txt =
  let prefix = T.replicate (n * 4) " "
  in T.unlines $ map (\line -> if T.null line then line else prefix <> line) (T.lines txt)

-- ---------------------------------------------------------------------------
-- Type utilities
-- ---------------------------------------------------------------------------

-- | Get the default zero value for a C primitive type
cTypeDefault :: Text -> Text
cTypeDefault typeName
  | isPrimitiveFloat typeName = "0.0"
  | isPrimitiveNumeric typeName = "0"
  | otherwise = "0"

-- | Get the printf format specifier for a C primitive type
cFormatSpecifier :: Text -> Text
cFormatSpecifier typeName = case typeName of
  "int"            -> "%d"
  "long"           -> "%ld"
  "short"          -> "%hd"
  "char"           -> "%c"
  "unsigned"       -> "%u"
  "unsigned int"   -> "%u"
  "unsigned long"  -> "%lu"
  "unsigned short" -> "%hu"
  "size_t"         -> "%zu"
  "uint8_t"        -> "%\" PRIu8 \""
  "uint16_t"       -> "%\" PRIu16 \""
  "uint32_t"       -> "%\" PRIu32 \""
  "uint64_t"       -> "%\" PRIu64 \""
  "int8_t"         -> "%\" PRId8 \""
  "int16_t"        -> "%\" PRId16 \""
  "int32_t"        -> "%\" PRId32 \""
  "int64_t"        -> "%\" PRId64 \""
  "float"          -> "%f"
  "double"         -> "%lf"
  _                -> "%d"

-- | Check if a type name is a numeric primitive (integer-like)
isPrimitiveNumeric :: Text -> Bool
isPrimitiveNumeric typeName =
  typeName `elem`
    [ "int", "long", "short", "char", "size_t"
    , "uint8_t", "uint16_t", "uint32_t", "uint64_t"
    , "int8_t", "int16_t", "int32_t", "int64_t"
    , "unsigned", "unsigned int", "unsigned long", "unsigned short"
    ]

-- | Check if a type name is a floating-point primitive
isPrimitiveFloat :: Text -> Bool
isPrimitiveFloat typeName =
  typeName `elem` ["float", "double"]

-- | Generate the conventional function name for a struct operation
--
-- @structFuncName \"Person\" \"init\"@ produces @\"person_init\"@
structFuncName :: Text -> Text -> Text
structFuncName structName operation =
  T.toLower structName <> "_" <> operation

-- ---------------------------------------------------------------------------
-- Code assembly
-- ---------------------------------------------------------------------------

-- | Assemble a function from its parts, filtering out empty sections
assembleFunction :: [Text] -> Text
assembleFunction = T.unlines . filterEmpty

-- | Filter out empty text values from a list
filterEmpty :: [Text] -> [Text]
filterEmpty = filter (not . T.null)
