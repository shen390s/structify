{-# LANGUAGE OverloadedStrings #-}

-- | Extract attributes into IR
--
-- This module merges parsed C structures with their structify annotations
-- to create enriched IR suitable for code generation.
module Structify.Transform.Enricher
  ( -- * Enrichment functions
    enrichStructs
  , enrichStruct
  , enrichField

  -- * Error types
  , EnrichmentError(..)
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Maybe (fromMaybe)

-- Import parser types
import qualified Structify.Parser.C as C
import qualified Structify.Parser.Attribute as A

-- Import IR types
import Structify.IR.Types

-- | Enrichment error
data EnrichmentError
  = UnknownFieldReference FieldName StructName
  | InvalidAnnotation Text
  | TypeConversionError Text
  deriving (Eq, Show)

-- | Enrich multiple structs from parse results
enrichStructs :: C.ParseResult -> Either EnrichmentError [EnrichedStruct]
enrichStructs parseResult = do
  mapM enrichStruct (C.prStructs parseResult)

-- | Enrich a single struct with its annotations
enrichStruct :: C.CStructDecl -> Either EnrichmentError EnrichedStruct
enrichStruct cStruct = do
  -- Convert struct name
  let structName = StructName (C.csdName cStruct)

  -- Parse struct-level annotations
  let structAnnots = A.parseStructAnnotations (C.csdAttributes cStruct)

  -- Enrich all fields
  enrichedFields <- mapM (enrichField structName) (C.csdFields cStruct)

  -- Create source location if available
  let location = case C.csdLocation cStruct of
        Just (file, line, col) -> Just $ SourceLocation file line col
        Nothing -> Nothing

  return $ EnrichedStruct
    { esName = structName
    , esFields = enrichedFields
    , esAnnotations = convertStructAnnotations structAnnots
    , esLocation = location
    }

-- | Enrich a single field with its annotations
enrichField :: StructName -> C.CFieldDecl -> Either EnrichmentError EnrichedField
enrichField _structName cField = do
  -- Convert field name
  let fieldName = FieldName (C.cfdName cField)

  -- Parse field-level annotations
  let fieldAnnots = A.parseFieldAnnotations (C.cfdAttributes cField)

  -- Convert type
  enrichedType <- convertType (C.cfdType cField) (A.faOwnership fieldAnnots)

  -- Create source location if available
  let location = case C.cfdLocation cField of
        Just (file, line, col) -> Just $ SourceLocation file line col
        Nothing -> Nothing

  return $ EnrichedField
    { efName = fieldName
    , efType = enrichedType
    , efAnnotations = convertFieldAnnotations fieldAnnots
    , efBitField = C.cfdBitField cField
    , efLocation = location
    }

-- | Convert C type to enriched type
convertType :: C.CType -> Maybe A.Ownership -> Either EnrichmentError EnrichedType
convertType cType ownership = case cType of
  C.CPrimitive name -> Right $ PrimitiveType name

  C.CPointer innerType -> do
    innerEnriched <- convertType innerType Nothing
    let ownershipValue = fromMaybe Borrowed (convertOwnership <$> ownership)
    Right $ PointerType innerEnriched ownershipValue

  C.CArray innerType size -> do
    innerEnriched <- convertType innerType Nothing
    Right $ ArrayType innerEnriched size

  C.CStruct name -> Right $ StructType (StructName name)

  C.CTypedef name -> Right $ TypedefType (TypeName name)

  C.CFunctionPtr -> Right FunctionPointerType

  C.CUnknown name -> Right $ UnknownType name

-- | Convert ownership from parser to IR
convertOwnership :: A.Ownership -> Ownership
convertOwnership A.Owned = Owned
convertOwnership A.Borrowed = Borrowed
convertOwnership A.Shared = Shared

-- | Convert field annotations from parser to IR
convertFieldAnnotations :: A.FieldAnnotations -> FieldAnnotations
convertFieldAnnotations annots = FieldAnnotations
  { faDefault = A.faDefault annots
  , faLengthField = FieldName <$> A.faLengthField annots
  , faCustomInit = FunctionName <$> A.faCustomInit annots
  , faCustomCleanup = FunctionName <$> A.faCustomCleanup annots
  , faDeepCopy = A.faDeepCopy annots
  , faNoCopy = A.faNoCopy annots
  , faNoPrint = A.faNoPrint annots
  , faPrintFormat = A.faPrintFormat annots
  , faNoEqual = A.faNoEqual annots
  , faNoHash = A.faNoHash annots
  , faCustomHash = FunctionName <$> A.faCustomHash annots
  , faOwnership = convertOwnership <$> A.faOwnership annots
  , faAllocator = FunctionName <$> A.faAllocator annots
  , faDeallocator = FunctionName <$> A.faDeallocator annots
  }

-- | Convert struct annotations from parser to IR
convertStructAnnotations :: A.StructAnnotations -> StructAnnotations
convertStructAnnotations annots = StructAnnotations
  { saPreInit = FunctionName <$> A.saPreInit annots
  , saPostInit = FunctionName <$> A.saPostInit annots
  , saPreCleanup = FunctionName <$> A.saPreCleanup annots
  , saPostCleanup = FunctionName <$> A.saPostCleanup annots
  , saNoInit = A.saNoInit annots
  , saNoCleanup = A.saNoCleanup annots
  , saNoCopy = A.saNoCopy annots
  , saNoPrint = A.saNoPrint annots
  , saNoEqual = A.saNoEqual annots
  , saNoHash = A.saNoHash annots
  , saPrintName = A.saPrintName annots
  , saHooks = A.saHooks annots
  }
