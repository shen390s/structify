{-# LANGUAGE OverloadedStrings #-}

-- | C header parsing wrapper using language-c
--
-- Note: This is a simplified implementation that parses basic C structs.
-- Full implementation will be completed in future iterations.
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
--
-- TODO: Implement full parsing using language-c
-- For now, returns empty result
parseHeader :: FilePath -> IO (Either ParseError ParseResult)
parseHeader path = do
  content <- TIO.readFile path
  return $ parseHeaderFromString path content

-- | Parse C header from string
--
-- TODO: Implement full parsing using language-c
-- For now, returns empty result
parseHeaderFromString :: FilePath -> Text -> Either ParseError ParseResult
parseHeaderFromString _filename _content = do
  -- Placeholder implementation
  -- Full implementation will use language-c library
  Right $ ParseResult
    { prStructs = []
    , prTypedefs = []
    , prEnums = []
    }
