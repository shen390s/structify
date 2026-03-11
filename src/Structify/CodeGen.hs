{-# LANGUAGE OverloadedStrings #-}

-- | Unified code generation module
--
-- This module provides a high-level interface for generating all C functions
-- for a struct: init, cleanup, copy, print, equal, and hash.
module Structify.CodeGen
  ( -- * Main generation function
    generateAllFunctions
  , GeneratedCode(..)

  -- * Re-exports from individual generators
  , module Structify.CodeGen.Init
  , module Structify.CodeGen.Cleanup
  , module Structify.CodeGen.Copy
  , module Structify.CodeGen.Print
  , module Structify.CodeGen.Equal
  , module Structify.CodeGen.Hash
  ) where

import Data.Text (Text)
import qualified Data.Text as T

import Structify.IR.Types
import Structify.CodeGen.Init
import Structify.CodeGen.Cleanup
import Structify.CodeGen.Copy
import Structify.CodeGen.Print
import Structify.CodeGen.Equal
import Structify.CodeGen.Hash

-- | All generated code for a struct
data GeneratedCode = GeneratedCode
  { gcHeaderDeclarations :: Text  -- ^ All function declarations for header file
  , gcSourceDefinitions :: Text   -- ^ All function definitions for source file
  , gcInitCode :: InitCode
  , gcCleanupCode :: CleanupCode
  , gcCopyCode :: CopyCode
  , gcPrintCode :: PrintCode
  , gcEqualCode :: EqualCode
  , gcHashCode :: HashCode
  } deriving (Eq, Show)

-- | Generate all functions for a struct
generateAllFunctions :: EnrichedStruct -> GeneratedCode
generateAllFunctions struct =
  let initCode = generateInitFunction struct
      cleanupCode = generateCleanupFunction struct
      copyCode = generateCopyFunction struct
      printCode = generatePrintFunction struct
      equalCode = generateEqualFunction struct
      hashCode = generateHashFunction struct

      -- Collect all declarations for header file
      headerDecls = T.unlines $ filter (not . T.null)
        [ "// Init function"
        , icDeclaration initCode
        , ""
        , "// Cleanup function"
        , ccDeclaration cleanupCode
        , ""
        , "// Copy function"
        , copyDeclaration copyCode
        , ""
        , "// Print function"
        , printDeclaration printCode
        , ""
        , "// Equality functions"
        , equalDeclaration equalCode
        , deepEqualDeclaration equalCode
        , ""
        , "// Hash function"
        , hashDeclaration hashCode
        ]

      -- Collect all definitions for source file
      sourceDefs = T.unlines $ filter (not . T.null)
        [ "// Init function"
        , icDefinition initCode
        , ""
        , "// Cleanup function"
        , ccDefinition cleanupCode
        , ""
        , "// Copy function"
        , copyDefinition copyCode
        , ""
        , "// Print function"
        , printDefinition printCode
        , ""
        , "// Equality functions"
        , equalDefinition equalCode
        , ""
        , deepEqualDefinition equalCode
        , ""
        , "// Hash function"
        , hashDefinition hashCode
        ]

  in GeneratedCode
     { gcHeaderDeclarations = headerDecls
     , gcSourceDefinitions = sourceDefs
     , gcInitCode = initCode
     , gcCleanupCode = cleanupCode
     , gcCopyCode = copyCode
     , gcPrintCode = printCode
     , gcEqualCode = equalCode
     , gcHashCode = hashCode
     }
