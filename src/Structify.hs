-- | Main library interface for Structify
module Structify
  ( -- * Main API
    generateCode
  , parseHeader
  , validateAnnotations

  -- * Re-exports
  , module Structify.IR.Types
  , module Structify.Error.Types
  ) where

import Structify.IR.Types
import Structify.Error.Types

-- | Parse a C header file and generate init/cleanup/copy/print/equal/hash functions
generateCode :: FilePath -> IO (Either StructifyError String)
generateCode _headerPath = do
  -- TODO: Implement
  return $ Left $ StructifyError "Not implemented yet"

-- | Parse a C header file and extract struct definitions
parseHeader :: FilePath -> IO (Either StructifyError [EnrichedStruct])
parseHeader _headerPath = do
  -- TODO: Implement
  return $ Left $ StructifyError "Not implemented yet"

-- | Validate structify annotations in a header file
validateAnnotations :: FilePath -> IO (Either StructifyError ())
validateAnnotations _headerPath = do
  -- TODO: Implement
  return $ Left $ StructifyError "Not implemented yet"
