-- | Error types for Structify
module Structify.Error.Types
  ( StructifyError(..)
  ) where

-- | Errors that can occur during code generation
newtype StructifyError = StructifyError String
  deriving (Eq, Show)
