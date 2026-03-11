-- | Core IR types for Structify
module Structify.IR.Types
  ( -- * Core types
    StructName(..)
  , FieldName(..)
  , FunctionName(..)
  , EnrichedStruct(..)
  , EnrichedField(..)
  , FieldAnnotations(..)
  , Ownership(..)
  ) where

import Data.Text (Text)

-- | Struct name
newtype StructName = StructName Text
  deriving (Eq, Ord, Show)

-- | Field name
newtype FieldName = FieldName Text
  deriving (Eq, Ord, Show)

-- | Function name
newtype FunctionName = FunctionName Text
  deriving (Eq, Ord, Show)

-- | Ownership semantics for pointers
data Ownership
  = Owned      -- ^ Field owns the memory, will be freed
  | Borrowed   -- ^ Field doesn't own memory, won't be freed
  | Shared     -- ^ Shared ownership (reference counted)
  deriving (Eq, Show)

-- | Field annotations from structify attributes
data FieldAnnotations = FieldAnnotations
  { faDefault :: Maybe Text
  , faLengthField :: Maybe FieldName
  , faCustomInit :: Maybe FunctionName
  , faCustomCleanup :: Maybe FunctionName
  , faDeepCopy :: Bool
  , faNoCopy :: Bool
  , faNoPrint :: Bool
  , faPrintFormat :: Maybe Text
  , faNoEqual :: Bool
  , faNoHash :: Bool
  , faCustomHash :: Maybe FunctionName
  , faOwnership :: Maybe Ownership
  } deriving (Eq, Show)

-- | Enriched field with annotations
data EnrichedField = EnrichedField
  { efName :: FieldName
  , efAnnotations :: FieldAnnotations
  -- TODO: Add type information
  } deriving (Eq, Show)

-- | Enriched struct with annotations
data EnrichedStruct = EnrichedStruct
  { esName :: StructName
  , esFields :: [EnrichedField]
  -- TODO: Add hooks and other metadata
  } deriving (Eq, Show)
