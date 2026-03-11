{-# LANGUAGE OverloadedStrings #-}

-- | Parse structify attributes from C AST
--
-- Note: This is a simplified implementation.
-- Full implementation will parse attributes from language-c AST.
module Structify.Parser.Attribute
  ( -- * Parsing functions
    parseFieldAnnotations
  , parseStructAnnotations

  -- * Types
  , FieldAnnotations(..)
  , StructAnnotations(..)
  , Ownership(..)
  , defaultFieldAnnotations
  , defaultStructAnnotations
  ) where

import Data.Text (Text)
import qualified Data.Text as T

-- | Ownership semantics for pointers
data Ownership
  = Owned      -- ^ Field owns the memory, will be freed
  | Borrowed   -- ^ Field doesn't own memory, won't be freed
  | Shared     -- ^ Shared ownership (reference counted)
  deriving (Eq, Show)

-- | Field-level annotations from structify attributes
data FieldAnnotations = FieldAnnotations
  { faDefault :: Maybe Text
  , faLengthField :: Maybe Text
  , faCustomInit :: Maybe Text
  , faCustomCleanup :: Maybe Text
  , faDeepCopy :: Bool
  , faNoCopy :: Bool
  , faNoPrint :: Bool
  , faPrintFormat :: Maybe Text
  , faNoEqual :: Bool
  , faNoHash :: Bool
  , faCustomHash :: Maybe Text
  , faOwnership :: Maybe Ownership
  , faAllocator :: Maybe Text
  , faDeallocator :: Maybe Text
  } deriving (Eq, Show)

-- | Struct-level annotations from structify attributes
data StructAnnotations = StructAnnotations
  { saPreInit :: Maybe Text
  , saPostInit :: Maybe Text
  , saPreCleanup :: Maybe Text
  , saPostCleanup :: Maybe Text
  , saNoInit :: Bool
  , saNoCleanup :: Bool
  , saNoCopy :: Bool
  , saNoPrint :: Bool
  , saNoEqual :: Bool
  , saNoHash :: Bool
  , saPrintName :: Maybe Text
  , saHooks :: Maybe Text
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

-- | Parse field-level annotations from attribute strings
--
-- TODO: Implement full parsing from language-c CAttr
-- For now, returns default annotations
parseFieldAnnotations :: [Text] -> FieldAnnotations
parseFieldAnnotations _attrs = defaultFieldAnnotations

-- | Parse struct-level annotations from attribute strings
--
-- TODO: Implement full parsing from language-c CAttr
-- For now, returns default annotations
parseStructAnnotations :: [Text] -> StructAnnotations
parseStructAnnotations _attrs = defaultStructAnnotations
