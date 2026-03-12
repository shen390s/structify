{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PackageImports #-}

-- | C header parsing using language-c library
module Structify.Parser.C
  ( -- * Parsing functions
    parseHeader
  , parseHeaderFromString

  -- * Types
  , ParseResult(..)
  , ParseError(..)
  , CStructDecl(..)
  , CFieldDecl(..)
  , CType(..)
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Data.Maybe (mapMaybe, catMaybes)
import Data.List (find)

-- language-c imports (package-qualified to avoid conflicts with language-c-quote)
import qualified "language-c" Language.C as LC
import qualified "language-c" Language.C.System.GCC as GCC
import qualified "language-c" Language.C.Data.Ident as Ident
import qualified "language-c" Language.C.Data.Position as Pos

-- | Result of parsing a C header file
data ParseResult = ParseResult
  { prStructs :: [CStructDecl]
  , prTypedefs :: [(Text, CType)]
  , prEnums :: [(Text, [Text])]
  } deriving (Eq, Show)

-- | Parse error information
data ParseError = ParseError
  { peMessage :: Text
  , peFile :: Maybe FilePath
  , peRow :: Maybe Int
  , peColumn :: Maybe Int
  } deriving (Eq, Show)

-- | C struct declaration
data CStructDecl = CStructDecl
  { csdName :: Text
  , csdFields :: [CFieldDecl]
  , csdAttributes :: [Text]  -- Simplified: just attribute names
  , csdLocation :: Maybe (FilePath, Int, Int)
  } deriving (Eq, Show)

-- | C field declaration
data CFieldDecl = CFieldDecl
  { cfdName :: Text
  , cfdType :: CType
  , cfdAttributes :: [Text]  -- Simplified: just attribute names
  , cfdBitField :: Maybe Int
  , cfdLocation :: Maybe (FilePath, Int, Int)
  } deriving (Eq, Show)

-- | Simplified C type representation
data CType
  = CPrimitive Text              -- int, char, etc.
  | CPointer CType               -- T*
  | CArray CType (Maybe Integer) -- T[n] or T[]
  | CStruct Text                 -- struct Name
  | CTypedef Text                -- typedef'd type
  | CFunctionPtr                 -- function pointer (simplified)
  | CUnknown Text                -- fallback for complex types
  deriving (Eq, Show)

-- | Parse a C header file
parseHeader :: FilePath -> IO (Either ParseError ParseResult)
parseHeader path = do
  -- Read the file and preprocess it
  content <- TIO.readFile path
  let preprocessed = simplePreprocess content
  return $ parseHeaderFromString path preprocessed

-- | Simple preprocessor that removes common directives that cause issues
-- but preserves the actual C code
simplePreprocess :: Text -> Text
simplePreprocess content =
  let -- First remove multi-line /* */ comments
      withoutBlockComments = removeBlockComments content
      -- Then process line by line
      lines' = T.lines withoutBlockComments
      -- Remove preprocessor directives but keep the code
      filtered = filter (not . isPreprocessorDirective) lines'
      -- Remove // comments from end of lines
      withoutLineComments = map removeLineComment filtered
  in T.unlines withoutLineComments
  where
    isPreprocessorDirective line =
      let trimmed = T.stripStart line
      in not (T.null trimmed) && T.head trimmed == '#'

    -- Remove // comments from end of line
    removeLineComment line =
      case T.breakOn "//" line of
        (before, after) | T.null after -> line
                       | otherwise -> T.stripEnd before

    -- Remove /* */ block comments
    removeBlockComments text =
      case T.breakOn "/*" text of
        (before, after) | T.null after -> text
                       | otherwise ->
                           case T.breakOn "*/" after of
                             (_, after2) | T.null after2 -> before  -- Unclosed comment
                                        | otherwise ->
                                            let rest = T.drop 2 after2  -- Skip */
                                            in before <> " " <> removeBlockComments rest

-- | Parse C header from string
parseHeaderFromString :: FilePath -> Text -> Either ParseError ParseResult
parseHeaderFromString filename content = do
  -- Parse using language-c (without preprocessing)
  let inputStream = LC.inputStreamFromString (T.unpack content)
  case LC.parseC inputStream (Pos.initPos filename) of
    Left err -> Left $ ParseError
      { peMessage = T.pack $ show err
      , peFile = Just filename
      , peRow = Nothing
      , peColumn = Nothing
      }
    Right (LC.CTranslUnit decls _) -> do
      -- Extract structs from declarations
      let structs = mapMaybe extractStruct decls
      let typedefs = mapMaybe extractTypedef decls
      let enums = mapMaybe extractEnum decls
      Right $ ParseResult
        { prStructs = structs
        , prTypedefs = typedefs
        , prEnums = enums
        }

-- | Extract struct declaration from C declaration
extractStruct :: LC.CExtDecl -> Maybe CStructDecl
extractStruct (LC.CDeclExt (LC.CDecl specs declarators _)) = do
  -- Look for struct in declaration specifiers
  structSpec <- find isStructSpec specs
  case structSpec of
    LC.CTypeSpec (LC.CSUType (LC.CStruct LC.CStructTag (Just ident) (Just fields) attrs _) _) -> do
      let name = T.pack $ Ident.identToString ident
      let fieldDecls = concatMap extractFields fields
      let attrStrs = map (T.pack . show) attrs
      Just $ CStructDecl
        { csdName = name
        , csdFields = fieldDecls
        , csdAttributes = attrStrs
        , csdLocation = Nothing  -- TODO: extract position
        }
    _ -> Nothing
  where
    isStructSpec (LC.CTypeSpec (LC.CSUType (LC.CStruct LC.CStructTag _ _ _ _) _)) = True
    isStructSpec _ = False
extractStruct _ = Nothing

-- | Extract typedef declaration
extractTypedef :: LC.CExtDecl -> Maybe (Text, CType)
extractTypedef (LC.CDeclExt (LC.CDecl specs declarators _)) = do
  -- Check if this is a typedef
  let hasTypedef = any isTypedefSpec specs
  if not hasTypedef then Nothing else do
    -- Get the type being typedef'd
    baseType <- extractTypeFromSpecs specs
    -- Get the new name
    case declarators of
      [(Just (LC.CDeclr (Just ident) _ _ _ _), _, _)] -> do
        let name = T.pack $ Ident.identToString ident
        Just (name, baseType)
      _ -> Nothing
  where
    isTypedefSpec (LC.CStorageSpec (LC.CTypedef _)) = True
    isTypedefSpec _ = False
extractTypedef _ = Nothing

-- | Extract enum declaration
extractEnum :: LC.CExtDecl -> Maybe (Text, [Text])
extractEnum (LC.CDeclExt (LC.CDecl specs _ _)) = do
  enumSpec <- find isEnumSpec specs
  case enumSpec of
    LC.CTypeSpec (LC.CEnumType (LC.CEnum (Just ident) (Just enumerators) _ _) _) -> do
      let name = T.pack $ Ident.identToString ident
      let values = map extractEnumerator enumerators
      Just (name, catMaybes values)
    _ -> Nothing
  where
    isEnumSpec (LC.CTypeSpec (LC.CEnumType _ _)) = True
    isEnumSpec _ = False
    extractEnumerator (ident, _) = Just $ T.pack $ Ident.identToString ident
extractEnum _ = Nothing

-- | Extract fields from struct declaration
extractFields :: LC.CDecl -> [CFieldDecl]
extractFields (LC.CDecl specs declarators _) = do
  let baseType = extractTypeFromSpecs specs
  case baseType of
    Nothing -> []
    Just ty -> mapMaybe (extractField ty) declarators

-- | Extract a single field from declarator
extractField :: CType -> (Maybe LC.CDeclr, Maybe LC.CInit, Maybe LC.CExpr) -> Maybe CFieldDecl
extractField baseType (Just (LC.CDeclr (Just ident) derivedDecls _ attrs _), _, bitField) = do
  let name = T.pack $ Ident.identToString ident
  let fieldType = applyDerivedDecls baseType derivedDecls
  let attrStrs = map (T.pack . show) attrs
  let bitFieldSize = case bitField of
        Just (LC.CConst (LC.CIntConst (LC.CInteger val _ _) _)) -> Just (fromInteger val)
        _ -> Nothing
  Just $ CFieldDecl
    { cfdName = name
    , cfdType = fieldType
    , cfdAttributes = attrStrs
    , cfdBitField = bitFieldSize
    , cfdLocation = Nothing  -- TODO: extract position
    }
extractField _ _ = Nothing

-- | Extract base type from declaration specifiers
extractTypeFromSpecs :: [LC.CDeclSpec] -> Maybe CType
extractTypeFromSpecs specs = do
  typeSpec <- find isTypeSpec specs
  case typeSpec of
    LC.CTypeSpec (LC.CVoidType _) -> Just $ CPrimitive "void"
    LC.CTypeSpec (LC.CCharType _) -> Just $ CPrimitive "char"
    LC.CTypeSpec (LC.CShortType _) -> Just $ CPrimitive "short"
    LC.CTypeSpec (LC.CIntType _) -> Just $ CPrimitive "int"
    LC.CTypeSpec (LC.CLongType _) -> Just $ CPrimitive "long"
    LC.CTypeSpec (LC.CFloatType _) -> Just $ CPrimitive "float"
    LC.CTypeSpec (LC.CDoubleType _) -> Just $ CPrimitive "double"
    LC.CTypeSpec (LC.CSignedType _) -> Just $ CPrimitive "signed"
    LC.CTypeSpec (LC.CUnsigType _) -> Just $ CPrimitive "unsigned"
    LC.CTypeSpec (LC.CBoolType _) -> Just $ CPrimitive "_Bool"
    LC.CTypeSpec (LC.CTypeDef ident _) -> Just $ CTypedef $ T.pack $ Ident.identToString ident
    LC.CTypeSpec (LC.CSUType (LC.CStruct _ (Just ident) _ _ _) _) -> Just $ CStruct $ T.pack $ Ident.identToString ident
    LC.CTypeSpec (LC.CEnumType (LC.CEnum (Just ident) _ _ _) _) -> Just $ CTypedef $ T.pack $ Ident.identToString ident
    _ -> Just $ CUnknown "complex_type"
  where
    isTypeSpec (LC.CTypeSpec _) = True
    isTypeSpec _ = False

-- | Apply derived declarators (pointers, arrays) to base type
applyDerivedDecls :: CType -> [LC.CDerivedDeclr] -> CType
applyDerivedDecls = foldl applyDerivedDecl

-- | Apply a single derived declarator
applyDerivedDecl :: CType -> LC.CDerivedDeclr -> CType
applyDerivedDecl ty (LC.CPtrDeclr _ _) = CPointer ty
applyDerivedDecl ty (LC.CArrDeclr _ (LC.CArrSize _ (LC.CConst (LC.CIntConst (LC.CInteger val _ _) _))) _) =
  CArray ty (Just val)
applyDerivedDecl ty (LC.CArrDeclr _ _ _) = CArray ty Nothing
applyDerivedDecl _ (LC.CFunDeclr _ _ _) = CFunctionPtr
