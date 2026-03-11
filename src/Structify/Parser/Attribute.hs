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

import qualified Language.C as C
import Language.C.Data.Ident (Ident(..))
import Data.Text (Text)
import qualified Data.Text as T
import Data.Maybe (mapMaybe, listToMaybe, fromMaybe)
import Data.List (find)

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

-- | Parse field-level annotations from C attributes
parseFieldAnnotations :: [C.CAttr] -> FieldAnnotations
parseFieldAnnotations attrs =
  let structifyAttrs = findStructifyAttributes attrs
  in foldr applyFieldAnnotation defaultFieldAnnotations structifyAttrs

-- | Parse struct-level annotations from C attributes
parseStructAnnotations :: [C.CAttr] -> StructAnnotations
parseStructAnnotations attrs =
  let structifyAttrs = findStructifyAttributes attrs
  in foldr applyStructAnnotation defaultStructAnnotations structifyAttrs

-- | Find all structify attributes in the attribute list
findStructifyAttributes :: [C.CAttr] -> [C.CAttr]
findStructifyAttributes = filter isStructifyAttr
  where
    isStructifyAttr (C.CAttr (Ident name _ _) _ _) = name == "structify"

-- | Apply a single structify attribute to field annotations
applyFieldAnnotation :: C.CAttr -> FieldAnnotations -> FieldAnnotations
applyFieldAnnotation (C.CAttr _ exprs _) annots =
  foldr processExpr annots exprs
  where
    processExpr expr acc = case expr of
      -- Simple identifiers: owned, borrowed, shared, deep_copy, no_copy, etc.
      C.CVar (Ident name _ _) _ -> case name of
        "owned" -> acc { faOwnership = Just Owned }
        "borrowed" -> acc { faOwnership = Just Borrowed }
        "shared" -> acc { faOwnership = Just Shared }
        "deep_copy" -> acc { faDeepCopy = True }
        "no_copy" -> acc { faNoCopy = True }
        "no_print" -> acc { faNoPrint = True }
        "no_equal" -> acc { faNoEqual = True }
        "no_hash" -> acc { faNoHash = True }
        _ -> acc

      -- Key-value pairs: default="value", length="field", etc.
      C.CAssign C.CAssignOp (C.CVar (Ident key _ _) _) value _ -> case key of
        "default" -> acc { faDefault = extractStringLiteral value }
        "length" -> acc { faLengthField = extractStringLiteral value }
        "init" -> acc { faCustomInit = extractStringLiteral value }
        "cleanup" -> acc { faCustomCleanup = extractStringLiteral value }
        "print_format" -> acc { faPrintFormat = extractStringLiteral value }
        "hash" -> acc { faCustomHash = extractStringLiteral value }
        "allocator" -> acc { faAllocator = extractStringLiteral value }
        "deallocator" -> acc { faDeallocator = extractStringLiteral value }
        _ -> acc

      _ -> acc

-- | Apply a single structify attribute to struct annotations
applyStructAnnotation :: C.CAttr -> StructAnnotations -> StructAnnotations
applyStructAnnotation (C.CAttr _ exprs _) annots =
  foldr processExpr annots exprs
  where
    processExpr expr acc = case expr of
      -- Simple identifiers: no_init, no_cleanup, etc.
      C.CVar (Ident name _ _) _ -> case name of
        "no_init" -> acc { saNoInit = True }
        "no_cleanup" -> acc { saNoCleanup = True }
        "no_copy" -> acc { saNoCopy = True }
        "no_print" -> acc { saNoPrint = True }
        "no_equal" -> acc { saNoEqual = True }
        "no_hash" -> acc { saNoHash = True }
        _ -> acc

      -- Key-value pairs: pre_init="func", post_init="func", etc.
      C.CAssign C.CAssignOp (C.CVar (Ident key _ _) _) value _ -> case key of
        "pre_init" -> acc { saPreInit = extractStringLiteral value }
        "post_init" -> acc { saPostInit = extractStringLiteral value }
        "pre_cleanup" -> acc { saPreCleanup = extractStringLiteral value }
        "post_cleanup" -> acc { saPostCleanup = extractStringLiteral value }
        "print_name" -> acc { saPrintName = extractStringLiteral value }
        "hooks" -> acc { saHooks = extractStringLiteral value }
        _ -> acc

      _ -> acc

-- | Extract string literal from C expression
extractStringLiteral :: C.CExpr -> Maybe Text
extractStringLiteral (C.CConst (C.CStrConst (C.CString str _) _)) =
  Just (T.pack str)
extractStringLiteral _ = Nothing
