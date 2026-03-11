{-# LANGUAGE OverloadedStrings #-}

-- | Parse structify attributes from C AST
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
import Data.Maybe (mapMaybe)

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
-- Parses structify attributes like: __attribute__((structify(owned, default="NULL")))
parseFieldAnnotations :: [Text] -> FieldAnnotations
parseFieldAnnotations attrs =
  foldr parseOneAttr defaultFieldAnnotations attrs
  where
    parseOneAttr attr annots =
      case parseStructifyAttr attr of
        Nothing -> annots
        Just pairs -> foldr applyPair annots pairs

    applyPair ("owned", _) annots = annots { faOwnership = Just Owned }
    applyPair ("borrowed", _) annots = annots { faOwnership = Just Borrowed }
    applyPair ("shared", _) annots = annots { faOwnership = Just Shared }
    applyPair ("default", Just val) annots = annots { faDefault = Just val }
    applyPair ("length", Just val) annots = annots { faLengthField = Just val }
    applyPair ("custom_init", Just val) annots = annots { faCustomInit = Just val }
    applyPair ("custom_cleanup", Just val) annots = annots { faCustomCleanup = Just val }
    applyPair ("deep_copy", _) annots = annots { faDeepCopy = True }
    applyPair ("no_copy", _) annots = annots { faNoCopy = True }
    applyPair ("no_print", _) annots = annots { faNoPrint = True }
    applyPair ("print_format", Just val) annots = annots { faPrintFormat = Just val }
    applyPair ("no_equal", _) annots = annots { faNoEqual = True }
    applyPair ("no_hash", _) annots = annots { faNoHash = True }
    applyPair ("custom_hash", Just val) annots = annots { faCustomHash = Just val }
    applyPair ("allocator", Just val) annots = annots { faAllocator = Just val }
    applyPair ("deallocator", Just val) annots = annots { faDeallocator = Just val }
    applyPair _ annots = annots

-- | Parse struct-level annotations from attribute strings
parseStructAnnotations :: [Text] -> StructAnnotations
parseStructAnnotations attrs =
  foldr parseOneAttr defaultStructAnnotations attrs
  where
    parseOneAttr attr annots =
      case parseStructifyAttr attr of
        Nothing -> annots
        Just pairs -> foldr applyPair annots pairs

    applyPair ("pre_init", Just val) annots = annots { saPreInit = Just val }
    applyPair ("post_init", Just val) annots = annots { saPostInit = Just val }
    applyPair ("pre_cleanup", Just val) annots = annots { saPreCleanup = Just val }
    applyPair ("post_cleanup", Just val) annots = annots { saPostCleanup = Just val }
    applyPair ("no_init", _) annots = annots { saNoInit = True }
    applyPair ("no_cleanup", _) annots = annots { saNoCleanup = True }
    applyPair ("no_copy", _) annots = annots { saNoCopy = True }
    applyPair ("no_print", _) annots = annots { saNoPrint = True }
    applyPair ("no_equal", _) annots = annots { saNoEqual = True }
    applyPair ("no_hash", _) annots = annots { saNoHash = True }
    applyPair ("print_name", Just val) annots = annots { saPrintName = Just val }
    applyPair ("hooks", Just val) annots = annots { saHooks = Just val }
    applyPair _ annots = annots

-- | Parse a structify attribute string into key-value pairs
--
-- Example: "CAttrGnuC (Ident \"structify\" ...) [...]"
-- -> Just [("owned", Nothing), ("default", Just "NULL")]
parseStructifyAttr :: Text -> Maybe [(Text, Maybe Text)]
parseStructifyAttr attr
  | "structify" `T.isInfixOf` attr = Just $ parseAttrContent attr
  | otherwise = Nothing
  where
    -- Simple parser for attribute content
    -- This is a simplified implementation - full version would use a proper parser
    parseAttrContent :: Text -> [(Text, Maybe Text)]
    parseAttrContent txt =
      let -- Extract content between parentheses after "structify"
          afterStructify = T.dropWhile (/= '(') $ snd $ T.breakOn "structify" txt
          content = T.takeWhile (/= ')') $ T.drop 1 afterStructify
          -- Split by commas
          parts = map T.strip $ T.splitOn "," content
      in mapMaybe parsePart parts

    parsePart :: Text -> Maybe (Text, Maybe Text)
    parsePart part
      | T.null part = Nothing
      | "=" `T.isInfixOf` part =
          let (key, val) = T.breakOn "=" part
              cleanVal = T.strip $ T.dropWhile (== '=') val
              -- Remove quotes
              unquoted = T.dropAround (\c -> c == '"' || c == '\'') cleanVal
          in Just (T.strip key, Just unquoted)
      | otherwise = Just (T.strip part, Nothing)
