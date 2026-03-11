{-# LANGUAGE OverloadedStrings #-}

-- | Core IR types for Structify
module Structify.IR.Types
  ( -- * Core types
    StructName(..)
  , FieldName(..)
  , FunctionName(..)
  , TypeName(..)

  -- * Enriched types
  , EnrichedStruct(..)
  , EnrichedField(..)
  , EnrichedType(..)
  , FieldAnnotations(..)
  , StructAnnotations(..)
  , Ownership(..)

  -- * Source location
  , SourceLocation(..)

  -- * Helper functions
  , defaultFieldAnnotations
  , defaultStructAnnotations
  ) where

import Data.Text (Text)
import qualified Data.Text as T

-- | Struct name
newtype StructName = StructName Text
  deriving (Eq, Ord, Show)

-- | Field name
newtype FieldName = FieldName Text
  deriving (Eq, Ord, Show)

-- | Function name
newtype FunctionName = FunctionName Text
  deriving (Eq, Ord, Show)

-- | Type name (for typedefs)
newtype TypeName = TypeName Text
  deriving (Eq, Ord, Show)

-- | Source location information
data SourceLocation = SourceLocation
  { slFile :: FilePath
  , slLine :: Int
  , slColumn :: Int
  } deriving (Eq, Show)

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
  , faAllocator :: Maybe FunctionName
  , faDeallocator :: Maybe FunctionName
  } deriving (Eq, Show)

-- | Struct annotations from structify attributes
data StructAnnotations = StructAnnotations
  { saPreInit :: Maybe FunctionName
  , saPostInit :: Maybe FunctionName
  , saPreCleanup :: Maybe FunctionName
  , saPostCleanup :: Maybe FunctionName
  , saNoInit :: Bool
  , saNoCleanup :: Bool
  , saNoCopy :: Bool
  , saNoPrint :: Bool
  , saNoEqual :: Bool
  , saNoHash :: Bool
  , saPrintName :: Maybe Text
  , saHooks :: Maybe Text
  } deriving (Eq, Show)

-- | Enriched type with ownership and annotation information
data EnrichedType
  = PrimitiveType Text                    -- ^ int, char, float, etc.
  | PointerType EnrichedType Ownership    -- ^ T* with ownership
  | ArrayType EnrichedType (Maybe Integer) -- ^ T[n] or T[]
  | StructType StructName                 -- ^ struct Name
  | TypedefType TypeName                  -- ^ typedef'd type
  | FunctionPointerType                   -- ^ function pointer (simplified)
  | UnknownType Text                      -- ^ fallback for complex types
  deriving (Eq, Show)

-- | Enriched field with type and annotations
data EnrichedField = EnrichedField
  { efName :: FieldName
  , efType :: EnrichedType
  , efAnnotations :: FieldAnnotations
  , efBitField :: Maybe Int
  , efLocation :: Maybe SourceLocation
  } deriving (Eq, Show)

-- | Enriched struct with fields and annotations
data EnrichedStruct = EnrichedStruct
  { esName :: StructName
  , esFields :: [EnrichedField]
  , esAnnotations :: StructAnnotations
  , esLocation :: Maybe SourceLocation
  } deriving (Eq, Show)

-- | Default field annotations (all disabled)
defaultFieldAnnotations :: FieldAnnotations
defaultFieldAnnotations = FieldAnnotations
  { faDefault = Nothing
  , faLengthField = Nothing
  , faCustomInit = Nothing
  , faCustomCleanup = Nothing
  , faDeepCopy = False
  , faNoCopy = False
  , faNoPrint = False
  , faPrintFormat = Nothing
  , faNoEqual = False
  , faNoHash = False
  , faCustomHash = Nothing
  , faOwnership = Nothing
  , faAllocator = Nothing
  , faDeallocator = Nothing
  }

-- | Default struct annotations (all disabled)
defaultStructAnnotations :: StructAnnotations
defaultStructAnnotations = StructAnnotations
  { saPreInit = Nothing
  , saPostInit = Nothing
  , saPreCleanup = Nothing
  , saPostCleanup = Nothing
  , saNoInit = False
  , saNoCleanup = False
  , saNoCopy = False
  , saNoPrint = False
  , saNoEqual = False
  , saNoHash = False
  , saPrintName = Nothing
  , saHooks = Nothing
  }
