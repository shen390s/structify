{-# LANGUAGE OverloadedStrings #-}

-- | Command-line options parsing
module Structify.CLI.Options
  ( -- * Options
    Options(..)
  , Command(..)
  , GenerateOptions(..)
  , FunctionType(..)

  -- * Parsing
  , parseOptions
  , optionsParser
  ) where

import Options.Applicative
import Data.Text (Text)
import qualified Data.Text as T

-- | Main CLI options
data Options = Options
  { optCommand :: Command
  , optVerbose :: Bool
  } deriving (Eq, Show)

-- | Available commands
data Command
  = Generate GenerateOptions
  | Validate FilePath
  | Info FilePath
  deriving (Eq, Show)

-- | Options for the generate command
data GenerateOptions = GenerateOptions
  { genInputFile :: FilePath
  , genOutputHeader :: Maybe FilePath
  , genOutputSource :: Maybe FilePath
  , genOnly :: [FunctionType]
  } deriving (Eq, Show)

-- | Types of functions that can be generated
data FunctionType
  = FuncInit
  | FuncCleanup
  | FuncCopy
  | FuncPrint
  | FuncEqual
  | FuncHash
  deriving (Eq, Show, Read)

-- | Parse command-line options
parseOptions :: IO Options
parseOptions = execParser opts
  where
    opts = info (optionsParser <**> helper)
      ( fullDesc
     <> progDesc "Generate C functions for structs with structify annotations"
     <> header "structify - C code generator for annotated structs" )

-- | Options parser
optionsParser :: Parser Options
optionsParser = Options
  <$> commandParser
  <*> switch
      ( long "verbose"
     <> short 'v'
     <> help "Enable verbose output" )

-- | Command parser
commandParser :: Parser Command
commandParser = subparser
  ( command "generate"
    ( info generateParser
      ( progDesc "Generate C code from annotated header file" ))
 <> command "validate"
    ( info validateParser
      ( progDesc "Validate structify annotations in header file" ))
 <> command "info"
    ( info structInfoParser
      ( progDesc "Show information about structs in header file" ))
  )

-- | Generate command parser
generateParser :: Parser Command
generateParser = Generate <$> (GenerateOptions
  <$> argument str
      ( metavar "INPUT"
     <> help "Input C header file" )
  <*> optional (strOption
      ( long "output-header"
     <> short 'H'
     <> metavar "FILE"
     <> help "Output header file (default: INPUT_generated.h)" ))
  <*> optional (strOption
      ( long "output-source"
     <> short 'C'
     <> metavar "FILE"
     <> help "Output source file (default: INPUT_generated.c)" ))
  <*> many (option auto
      ( long "only"
     <> short 'o'
     <> metavar "FUNC"
     <> help "Generate only specific functions (init, cleanup, copy, print, equal, hash)" ))
  )

-- | Validate command parser
validateParser :: Parser Command
validateParser = Validate <$> argument str
  ( metavar "INPUT"
 <> help "Input C header file to validate" )

-- | Info command parser
structInfoParser :: Parser Command
structInfoParser = Info <$> argument str
  ( metavar "INPUT"
 <> help "Input C header file to analyze" )

-- | Convert function type to string
functionTypeToString :: FunctionType -> String
functionTypeToString FuncInit = "init"
functionTypeToString FuncCleanup = "cleanup"
functionTypeToString FuncCopy = "copy"
functionTypeToString FuncPrint = "print"
functionTypeToString FuncEqual = "equal"
functionTypeToString FuncHash = "hash"

-- | Parse function type from string
parseFunctionType :: String -> Maybe FunctionType
parseFunctionType "init" = Just FuncInit
parseFunctionType "cleanup" = Just FuncCleanup
parseFunctionType "copy" = Just FuncCopy
parseFunctionType "print" = Just FuncPrint
parseFunctionType "equal" = Just FuncEqual
parseFunctionType "hash" = Just FuncHash
parseFunctionType _ = Nothing
