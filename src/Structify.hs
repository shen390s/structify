-- | Main library interface for Structify
module Structify
  ( -- * Main API
    generateCode
  , parseHeader
  , validateAnnotations
  , enrichHeader

  -- * Re-exports from IR
  , module Structify.IR.Types

  -- * Re-exports from Parser
  , ParseResult
  , ParseError

  -- * Re-exports from Transform
  , EnrichmentError
  , enrichStructs
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import Structify.IR.Types
import Structify.Parser.C (ParseResult, ParseError, parseHeader, parseHeaderFromString)
import Structify.Transform.Enricher (EnrichmentError, enrichStructs)
import Structify.CodeGen (generateAllFunctions, GeneratedCode(..))
import qualified Structify.Parser.C as C

-- | Parse and enrich a C header file
enrichHeader :: FilePath -> IO (Either String [EnrichedStruct])
enrichHeader path = do
  parseResult <- parseHeader path
  case parseResult of
    Left err -> return $ Left $ "Parse error: " ++ show err
    Right result -> case enrichStructs result of
      Left enrichErr -> return $ Left $ "Enrichment error: " ++ show enrichErr
      Right structs -> return $ Right structs

-- | Parse a C header file and generate init/cleanup/copy/print/equal/hash functions
--
-- Returns a tuple of (header_content, source_content)
generateCode :: FilePath -> IO (Either String (Text, Text))
generateCode headerPath = do
  enrichResult <- enrichHeader headerPath
  case enrichResult of
    Left err -> return $ Left err
    Right structs -> do
      -- Generate code for all structs
      let allGenerated = map generateAllFunctions structs

      -- Combine all declarations and definitions
      let headerDecls = T.unlines $ map gcHeaderDeclarations allGenerated
      let sourceDefns = T.unlines $ map gcSourceDefinitions allGenerated

      return $ Right (headerDecls, sourceDefns)

-- | Validate structify annotations in a header file
--
-- TODO: Implement validation
validateAnnotations :: FilePath -> IO (Either String ())
validateAnnotations _headerPath = do
  return $ Left "Validation not yet implemented"
