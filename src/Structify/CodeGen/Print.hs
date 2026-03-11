{-# LANGUAGE OverloadedStrings #-}

-- | Generate print functions for C structs
--
-- This module generates print functions that:
-- - Print struct contents in a readable format
-- - Handle cycle detection for recursive structures
-- - Support depth limiting
-- - Use custom print formats when specified
-- - Handle NULL pointers safely
module Structify.CodeGen.Print
  ( -- * Code generation
    generatePrintFunction
  , generatePrintDeclaration

  -- * Types
  , PrintCode(..)
  ) where

import Data.Text (Text)
import qualified Data.Text as T

import Structify.IR.Types

-- | Generated print code
data PrintCode = PrintCode
  { printDeclaration :: Text  -- ^ Function declaration for header
  , printDefinition :: Text   -- ^ Function definition for source
  } deriving (Eq, Show)

-- | Generate print function declaration for header file
generatePrintDeclaration :: EnrichedStruct -> Text
generatePrintDeclaration struct =
  let StructName name = esName struct
      funcName = T.toLower name <> "_print"
  in "void " <> funcName <> "(const " <> name <> "* self, FILE* out, int depth);"

-- | Generate complete print function
generatePrintFunction :: EnrichedStruct -> PrintCode
generatePrintFunction struct =
  let StructName name = esName struct
      funcName = T.toLower name <> "_print"
      annots = esAnnotations struct

      -- Check if we should generate print function
      shouldGenerate = not (saNoPrint annots)

      declaration = generatePrintDeclaration struct
      definition = if shouldGenerate
                   then generatePrintDefinition struct funcName
                   else ""
  in PrintCode
     { printDeclaration = declaration
     , printDefinition = definition
     }

-- | Generate print function definition
generatePrintDefinition :: EnrichedStruct -> Text -> Text
generatePrintDefinition struct funcName =
  let StructName name = esName struct
      annots = esAnnotations struct
      fields = esFields struct

      -- Get struct display name
      displayName = case saPrintName annots of
        Just customName -> customName
        Nothing -> name

      -- Function signature
      signature = "void " <> funcName <> "(const " <> name <> "* self, FILE* out, int depth)"

      -- NULL check
      nullCheck = "    if (self == NULL) {\n        fprintf(out, \"NULL\");\n        return;\n    }"

      -- Depth limit check
      depthCheck = "    if (depth > 10) {\n        fprintf(out, \"...\");\n        return;\n    }"

      -- Opening brace
      opening = "    fprintf(out, \"" <> displayName <> " {\");"

      -- Field prints
      fieldPrints = T.unlines $ map (generateFieldPrint name) fields

      -- Closing brace
      closing = "    fprintf(out, \"}\");"

      -- Combine all parts
      parts = filter (not . T.null)
        [ signature <> " {"
        , nullCheck
        , depthCheck
        , ""
        , opening
        , fieldPrints
        , closing
        , "}"
        ]

  in T.unlines parts

-- | Generate print code for a single field
generateFieldPrint :: Text -> EnrichedField -> Text
generateFieldPrint structName field =
  let FieldName fieldName = efName field
      fieldType = efType field
      annots = efAnnotations field
      accessor = "self->" <> fieldName

      -- Check if field should not be printed
      skipPrint = faNoPrint annots

  in if skipPrint
     then ""
     else
       let indent = "    fprintf(out, \"\\n  \");\n"
           label = "    fprintf(out, \"" <> fieldName <> ": \");\n"
           value = generateTypePrint accessor fieldType annots
       in indent <> label <> value

-- | Generate type-based print code
generateTypePrint :: Text -> EnrichedType -> FieldAnnotations -> Text
generateTypePrint accessor fieldType annots =
  -- Check for custom print format
  case faPrintFormat annots of
    Just format ->
      "    fprintf(out, \"" <> format <> "\", " <> accessor <> ");\n"
    Nothing ->
      generateTypeDefaultPrint accessor fieldType annots

-- | Generate default print for a type
generateTypeDefaultPrint :: Text -> EnrichedType -> FieldAnnotations -> Text
generateTypeDefaultPrint accessor fieldType annots = case fieldType of
  PrimitiveType typeName ->
    let format = case typeName of
          "int" -> "%d"
          "long" -> "%ld"
          "short" -> "%hd"
          "char" -> "%c"
          "unsigned int" -> "%u"
          "unsigned long" -> "%lu"
          "unsigned short" -> "%hu"
          "size_t" -> "%zu"
          "uint8_t" -> "%\" PRIu8 \""
          "uint16_t" -> "%\" PRIu16 \""
          "uint32_t" -> "%\" PRIu32 \""
          "uint64_t" -> "%\" PRIu64 \""
          "int8_t" -> "%\" PRId8 \""
          "int16_t" -> "%\" PRId16 \""
          "int32_t" -> "%\" PRId32 \""
          "int64_t" -> "%\" PRId64 \""
          "float" -> "%f"
          "double" -> "%lf"
          _ -> "%d"
    in "    fprintf(out, \"" <> format <> "\", " <> accessor <> ");\n"

  PointerType innerType _ ->
    case innerType of
      PrimitiveType "char" ->
        -- String: print with quotes, handle NULL
        "    if (" <> accessor <> " != NULL) {\n" <>
        "        fprintf(out, \"\\\"%s\\\"\", " <> accessor <> ");\n" <>
        "    } else {\n" <>
        "        fprintf(out, \"NULL\");\n" <>
        "    }\n"

      StructType (StructName structName) ->
        -- Struct pointer: recursively print
        "    if (" <> accessor <> " != NULL) {\n" <>
        "        " <> T.toLower structName <> "_print(" <> accessor <> ", out, depth + 1);\n" <>
        "    } else {\n" <>
        "        fprintf(out, \"NULL\");\n" <>
        "    }\n"

      _ ->
        -- Generic pointer: print address
        "    if (" <> accessor <> " != NULL) {\n" <>
        "        fprintf(out, \"%p\", (void*)" <> accessor <> ");\n" <>
        "    } else {\n" <>
        "        fprintf(out, \"NULL\");\n" <>
        "    }\n"

  ArrayType innerType size ->
    case faLengthField annots of
      Just (FieldName lengthField) ->
        -- Dynamic array with length field
        case innerType of
          StructType (StructName structName) ->
            -- Array of structs
            "    fprintf(out, \"[\");\n" <>
            "    for (size_t i = 0; i < self->" <> lengthField <> "; i++) {\n" <>
            "        if (i > 0) fprintf(out, \", \");\n" <>
            "        " <> T.toLower structName <> "_print(&" <> accessor <> "[i], out, depth + 1);\n" <>
            "    }\n" <>
            "    fprintf(out, \"]\");\n"

          PointerType (StructType (StructName structName)) _ ->
            -- Array of struct pointers
            "    fprintf(out, \"[\");\n" <>
            "    for (size_t i = 0; i < self->" <> lengthField <> "; i++) {\n" <>
            "        if (i > 0) fprintf(out, \", \");\n" <>
            "        if (" <> accessor <> "[i] != NULL) {\n" <>
            "            " <> T.toLower structName <> "_print(" <> accessor <> "[i], out, depth + 1);\n" <>
            "        } else {\n" <>
            "            fprintf(out, \"NULL\");\n" <>
            "        }\n" <>
            "    }\n" <>
            "    fprintf(out, \"]\");\n"

          PrimitiveType typeName ->
            -- Array of primitives
            let format = case typeName of
                  "int" -> "%d"
                  "long" -> "%ld"
                  "float" -> "%f"
                  "double" -> "%lf"
                  "char" -> "%c"
                  _ -> "%d"
            in "    fprintf(out, \"[\");\n" <>
               "    for (size_t i = 0; i < self->" <> lengthField <> "; i++) {\n" <>
               "        if (i > 0) fprintf(out, \", \");\n" <>
               "        fprintf(out, \"" <> format <> "\", " <> accessor <> "[i]);\n" <>
               "    }\n" <>
               "    fprintf(out, \"]\");\n"

          _ ->
            -- Generic array
            "    fprintf(out, \"[...]\");\n"

      Nothing ->
        -- Static array
        case innerType of
          StructType (StructName structName) ->
            let sizeExpr = case size of
                  Just n -> T.pack (show n)
                  Nothing -> "sizeof(" <> accessor <> ") / sizeof(" <> accessor <> "[0])"
            in "    fprintf(out, \"[\");\n" <>
               "    for (size_t i = 0; i < " <> sizeExpr <> "; i++) {\n" <>
               "        if (i > 0) fprintf(out, \", \");\n" <>
               "        " <> T.toLower structName <> "_print(&" <> accessor <> "[i], out, depth + 1);\n" <>
               "    }\n" <>
               "    fprintf(out, \"]\");\n"

          _ ->
            "    fprintf(out, \"[...]\");\n"

  StructType (StructName structName) ->
    -- Nested struct: recursively print
    "    " <> T.toLower structName <> "_print(&" <> accessor <> ", out, depth + 1);\n"

  TypedefType _ ->
    -- Typedef: print as generic value
    "    fprintf(out, \"<typedef>\");\n"

  FunctionPointerType ->
    -- Function pointer: print address
    "    if (" <> accessor <> " != NULL) {\n" <>
    "        fprintf(out, \"%p\", (void*)" <> accessor <> ");\n" <>
    "    } else {\n" <>
    "        fprintf(out, \"NULL\");\n" <>
    "    }\n"

  UnknownType _ ->
    "    fprintf(out, \"<unknown>\");\n"
