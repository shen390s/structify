{-# LANGUAGE OverloadedStrings #-}

-- | C header parsing wrapper using language-c
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

import qualified Language.C as C
import qualified Language.C.System.GCC as GCC
import Language.C.Data.Ident (Ident(..))
import Language.C.Data.Node (NodeInfo, posOfNode)
import Language.C.Data.Position (Position, posFile, posRow, posColumn)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Control.Monad (forM)
import Data.Maybe (mapMaybe, catMaybes)

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
  , csdAttributes :: [C.CAttr]
  , csdLocation :: Maybe (FilePath, Int, Int)
  } deriving (Eq, Show)

-- | C field declaration
data CFieldDecl = CFieldDecl
  { cfdName :: Text
  , cfdType :: CType
  , cfdAttributes :: [C.CAttr]
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
  content <- TIO.readFile path
  return $ parseHeaderFromString path content

-- | Parse C header from string
parseHeaderFromString :: FilePath -> Text -> Either ParseError ParseResult
parseHeaderFromString filename content = do
  -- Parse using language-c with GCC extensions
  translUnit <- case C.parseC (C.inputStreamFromString (T.unpack content)) (C.initPos filename) of
    Left err -> Left $ ParseError
      { peMessage = T.pack (show err)
      , peFile = Just filename
      , peRow = Nothing
      , peColumn = Nothing
      }
    Right tu -> Right tu

  -- Extract declarations
  let decls = case translUnit of
        C.CTranslUnit extDecls _ -> extDecls

  -- Extract structs, typedefs, and enums
  let structs = mapMaybe extractStruct decls
  let typedefs = mapMaybe extractTypedef decls
  let enums = mapMaybe extractEnum decls

  return $ ParseResult
    { prStructs = structs
    , prTypedefs = typedefs
    , prEnums = enums
    }

-- | Extract struct declaration from external declaration
extractStruct :: C.CExtDecl -> Maybe CStructDecl
extractStruct (C.CDeclExt (C.CDecl specs declarators _)) = do
  -- Look for struct in declaration specifiers
  structSpec <- findStructSpec specs
  case structSpec of
    C.CStructUnion C.CStructTag (Just (Ident name _ _)) (Just fields) attrs _ -> do
      fieldDecls <- mapM extractField fields
      return $ CStructDecl
        { csdName = T.pack name
        , csdFields = catMaybes fieldDecls
        , csdAttributes = attrs
        , csdLocation = Nothing -- TODO: extract location
        }
    _ -> Nothing
extractStruct _ = Nothing

-- | Find struct specification in declaration specifiers
findStructSpec :: [C.CDeclSpec] -> Maybe C.CStructUnion
findStructSpec [] = Nothing
findStructSpec (C.CTypeSpec (C.CSUType su _) : _) = Just su
findStructSpec (_ : rest) = findStructSpec rest

-- | Extract field from struct member declaration
extractField :: C.CDecl -> Maybe CFieldDecl
extractField (C.CDecl specs declarators _) = do
  -- Get the base type from specifiers
  let baseType = extractType specs

  -- Process each declarator (field)
  case declarators of
    [(Just (C.CDeclr (Just (Ident name _ _)) derivedDecls _ attrs _), initializer, bitField)] -> do
      let fieldType = applyDerivedDecls baseType derivedDecls
      let bitFieldSize = case bitField of
            Just (C.CExpr (Just (C.CConst (C.CIntConst i _))) _) -> Just (fromInteger (C.getCInteger i))
            _ -> Nothing

      return $ CFieldDecl
        { cfdName = T.pack name
        , cfdType = fieldType
        , cfdAttributes = attrs
        , cfdBitField = bitFieldSize
        , cfdLocation = Nothing -- TODO: extract location
        }
    _ -> Nothing

-- | Extract type from declaration specifiers
extractType :: [C.CDeclSpec] -> CType
extractType specs = go specs (CPrimitive "int") -- default to int
  where
    go [] acc = acc
    go (spec : rest) acc = case spec of
      C.CTypeSpec typeSpec -> go rest (extractTypeSpec typeSpec)
      _ -> go rest acc

-- | Extract type from type specifier
extractTypeSpec :: C.CTypeSpec -> CType
extractTypeSpec (C.CVoidType _) = CPrimitive "void"
extractTypeSpec (C.CCharType _) = CPrimitive "char"
extractTypeSpec (C.CShortType _) = CPrimitive "short"
extractTypeSpec (C.CIntType _) = CPrimitive "int"
extractTypeSpec (C.CLongType _) = CPrimitive "long"
extractTypeSpec (C.CFloatType _) = CPrimitive "float"
extractTypeSpec (C.CDoubleType _) = CPrimitive "double"
extractTypeSpec (C.CSignedType _) = CPrimitive "signed"
extractTypeSpec (C.CUnsigType _) = CPrimitive "unsigned"
extractTypeSpec (C.CBoolType _) = CPrimitive "_Bool"
extractTypeSpec (C.CSUType (C.CStructUnion _ (Just (Ident name _ _)) _ _ _) _) = CStruct (T.pack name)
extractTypeSpec (C.CTypeDef (Ident name _ _) _) = CTypedef (T.pack name)
extractTypeSpec _ = CUnknown "complex_type"

-- | Apply derived declarators (pointers, arrays) to base type
applyDerivedDecls :: CType -> [C.CDerivedDeclr] -> CType
applyDerivedDecls baseType [] = baseType
applyDerivedDecls baseType (decl : rest) = case decl of
  C.CPtrDeclr _ _ -> applyDerivedDecls (CPointer baseType) rest
  C.CArrDeclr _ (C.CArrSize _ (C.CConst (C.CIntConst i _))) _ ->
    applyDerivedDecls (CArray baseType (Just (C.getCInteger i))) rest
  C.CArrDeclr _ _ _ -> applyDerivedDecls (CArray baseType Nothing) rest
  C.CFunDeclr _ _ _ -> CFunctionPtr -- simplified

-- | Extract typedef from external declaration
extractTypedef :: C.CExtDecl -> Maybe (Text, CType)
extractTypedef (C.CDeclExt (C.CDecl specs declarators _)) = do
  -- Check if this is a typedef
  if any isTypedef specs
    then case declarators of
      [(Just (C.CDeclr (Just (Ident name _ _)) derivedDecls _ _ _), _, _)] -> do
        let baseType = extractType specs
        let finalType = applyDerivedDecls baseType derivedDecls
        return (T.pack name, finalType)
      _ -> Nothing
    else Nothing
  where
    isTypedef (C.CStorageSpec (C.CTypedef _)) = True
    isTypedef _ = False
extractTypedef _ = Nothing

-- | Extract enum from external declaration
extractEnum :: C.CExtDecl -> Maybe (Text, [Text])
extractEnum (C.CDeclExt (C.CDecl specs _ _)) = do
  enumSpec <- findEnumSpec specs
  case enumSpec of
    C.CEnum (Just (Ident name _ _)) (Just enumerators) _ _ -> do
      let enumValues = map extractEnumerator enumerators
      return (T.pack name, catMaybes enumValues)
    _ -> Nothing
  where
    findEnumSpec [] = Nothing
    findEnumSpec (C.CTypeSpec (C.CEnumType e _) : _) = Just e
    findEnumSpec (_ : rest) = findEnumSpec rest

    extractEnumerator (Ident name _ _, _) = Just (T.pack name)
extractEnum _ = Nothing
