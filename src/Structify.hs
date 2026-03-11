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

import Structify.IR.Types
import Structify.Parser.C (ParseResult, ParseError, parseHeader, parseHeaderFromString)
import Structify.Transform.Enricher (EnrichmentError, enrichStructs)
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
-- TODO: Implement code generation
generateCode :: FilePath -> IO (Either String String)
generateCode headerPath = do
  enrichResult <- enrichHeader headerPath
  case enrichResult of
    Left err -> return $ Left err
    Right _structs -> return $ Left "Code generation not yet implemented"

-- | Validate structify annotations in a header file
--
-- TODO: Implement validation
validateAnnotations :: FilePath -> IO (Either String ())
validateAnnotations _headerPath = do
  return $ Left "Validation not yet implemented"
