{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# LANGUAGE NamedFieldPuns    #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_HADDOCK hide #-}
module Etc.Internal.Resolver.File.Error where

import           RIO
import qualified RIO.Text as Text

import qualified Data.Aeson as JSON

import Data.Text.Prettyprint.Doc
import Data.Text.Prettyprint.Doc.Util (reflow)

import System.FilePath (takeExtension)

import Etc.Internal.Renderer
import Etc.Internal.Resolver.File.Types
import Etc.Internal.Spec.Types

--------------------------------------------------------------------------------
-- File Resolver

renderFileOrigin :: FileValueOrigin -> Doc Ann
renderFileOrigin origin = case origin of
  SpecFileOrigin path -> annotate Filepath (dquotes (pretty path))
  EnvFileOrigin (EnvOrigin env path) ->
    annotate Filepath (dquotes (pretty path))
      <+> "(from ENV"
      <+> annotate Envvar (dquotes (pretty env))
      <>  ")"

renderFileOrigin1 :: FileValueOrigin -> Doc Ann
renderFileOrigin1 origin = case origin of
  SpecFileOrigin path   -> annotate Filepath (dquotes (pretty path))
  EnvFileOrigin (EnvOrigin _env path) -> annotate Filepath (dquotes (pretty path))

getFileFromOrigin :: FileValueOrigin -> Doc ann
getFileFromOrigin origin = case origin of
  SpecFileOrigin path   -> dquotes (pretty path)
  EnvFileOrigin (EnvOrigin _env path) -> dquotes (pretty path)

--------------------------------------------------------------------------------
-- ConfigSpecFilesEntryMissing

configSpecFilesEntryMissingBody :: [Doc ann] -> Doc ann
configSpecFilesEntryMissingBody siblingKeys = vsep
  ([ reflow "I could not find the \"etc/files\" entry in the configuration spec file"
   ] <>
   if null siblingKeys
     then []
     else [ mempty
          , reflow "Other keys found in the configuration spec file"
          , mempty
          , indent 2 $ vsep $ map (<> ": ...") siblingKeys
          ])

renderConfigSpecFilesEntryMissingBody :: [Text] -> Doc Ann
renderConfigSpecFilesEntryMissingBody siblingKeys = foundError3
  "file resolver"
  (configSpecFilesEntryMissingBody (map pretty siblingKeys))
  [ reflow
      "Make sure to include the \"etc/files\" entry in your configuration spec file; more information at <PENDING_URL>"
  ]

--------------------------------------------------------------------------------
-- ConfigSpecFilesPathsEntryIsEmpty

renderConfigSpecFilesPathsEntryIsEmpty :: Doc Ann
renderConfigSpecFilesPathsEntryIsEmpty = foundError3
  "file resolver"
  ( reflow "The \"etc/files.path\" entry in your configuration spec file is empty")
  [ reflow
      "Make sure to have a valid \"etc/files\" entry in your configuration spec file, you can find more information at <PENDING_URL>"
  ]

--------------------------------------------------------------------------------
-- UnsupportedFileExtensionGiven

unsupportedFileExtensionGivenBody :: Doc Ann -> Doc Ann
unsupportedFileExtensionGivenBody filepath = vsep
  [ reflow "Detected a configuration file with an unsupported extension"
  , mempty
  , reflow "In the configuration spec file"
  , mempty
  , indent 2 $ renderKeyPathBody ["etc/files", "path"] $ newlineBody $ vsep
    ["- ...", annotate Error $ pointed ("-" <+> filepath), "- ..."]
  ]


renderUnsupportedFileExtensionGiven :: Text -> [Text] -> Doc Ann
renderUnsupportedFileExtensionGiven filepath supportedExtensions = foundError3
  "file resolver"
  (unsupportedFileExtensionGivenBody $ pretty filepath)
  (map
    (\supportedExtension ->
      reflow "Change the file extension from"
        <+> dquotes (pretty $ takeExtension (Text.unpack filepath))
        <+> reflow "to supported extension"
        <+> dquotes ("." <> pretty supportedExtension)
    )
    supportedExtensions
  )


--------------------------------------------------------------------------------
-- ConfigFileValueTypeMismatch

configFileValueTypeMismatchFoundBody
  :: FileValueOrigin -> Doc Ann -> [Doc Ann] -> ConfigValueType -> JSON.Value -> Doc Ann
configFileValueTypeMismatchFoundBody origin specFilePath keyPath cvType jsonVal =
  vsep
    [ reflow
        "I detected a mistmach between a configuration file value and the type specified in the configuration spec"
    , mempty
    , reflow "The configuration spec file located at" <+>
      annotate Filepath (dquotes specFilePath) <+>
      reflow "has the following type:"
    , mempty
    , indent 2 $
      renderSpecKeyPath keyPath $
      newlineBody $
      vsep
        [ hsep
            [ "type:"
            , annotate Expected $ pointed $ (renderConfigValueType cvType)
            ]
        ]
    , mempty
    , reflow "But the configuration file located at" <+>
      renderFileOrigin origin <+> reflow "has the following value:"
    , mempty
    , indent 2 $
      renderKeyPathBody keyPath $
      newlineBody $ annotate Current $ pointed $ renderJsonValue jsonVal
    , mempty
    , "The" <+>
      annotate Current "current value" <+>
      "does not match the" <+> annotate Expected "expected type"
    ]

renderConfigFileValueTypeMismatchFound
  :: FileValueOrigin -> Text -> [Text] -> ConfigValueType -> JSON.Value -> Doc Ann
renderConfigFileValueTypeMismatchFound origin specFilePath keyPath cvType jsonVal =
  foundError3
    "file resolver"
    (configFileValueTypeMismatchFoundBody
       origin
       (pretty specFilePath)
       (map pretty keyPath)
       cvType
       jsonVal)
    [ reflow
        "In the configuration file, change the entry value to match the type in the configuration spec"
    , case renderJsonType jsonVal of
        Just jsonTyDoc ->
          reflow "In the configuration spec file, change the entry \"type\" to" <+>
          dquotes jsonTyDoc <+> reflow "to match the configuration file value"
        Nothing -> mempty
    ]

--------------------------------------------------------------------------------
-- ConfigFileNotPresent

renderConfigFileNotPresent :: Text -> Doc Ann
renderConfigFileNotPresent filepath =
  let filepathDoc = dquotes (pretty filepath)
  in
    foundError3
      "file resolver"
      (vsep
        [ reflow "Didn't find a configuration file specified in the configuration spec file"
        , mempty
        , reflow "In the configuration spec file"
        , mempty
        , indent 2 $ renderKeyPathBody ["etc/files", "path"] $ newlineBody $ vsep
          ["- ...", annotate Error $ pointed ("-" <+> filepathDoc), "- ..."]
        ]
      )
      [reflow "Add a new configuration file at location" <+> annotate Filepath filepathDoc]

--------------------------------------------------------------------------------
-- UnknownConfigKeyFound

unknownConfigKeyFoundBody :: FileValueOrigin -> [Doc Ann] -> Doc Ann -> Doc Ann
unknownConfigKeyFoundBody fileSource keyPath unknownKey = vsep
  [ reflow
        "Detected a configuration file with an entry not present in the configuration spec file"
  , mempty
  , "On an entry in the configuration file" <+> renderFileOrigin fileSource
  , mempty
  , indent 2
  $ renderKeyPathBody keyPath
  $ newlineBody
  $ annotate Error
  $ pointed
  $ unknownKey <> ": ..."
  ]

renderUnknownConfigKeyFound :: FileValueOrigin -> [Text] -> Text -> Doc Ann
renderUnknownConfigKeyFound origin keyPath unknownKey =
  let
    keyPathDoc    = map pretty keyPath
    unknownKeyDoc = pretty unknownKey
  in
    foundError3
      "file resolver"
      (unknownConfigKeyFoundBody origin keyPathDoc unknownKeyDoc)
      [ reflow "Remove unknown entry"
      <+> dquotes unknownKeyDoc
      <+> reflow "from the configuration file"
      <+> renderFileOrigin1 origin
      , vsep
        [ reflow "Add the following entry to your configuration spec file:"
        , mempty
        , indent 4 $ renderSpecKeyPath (keyPathDoc ++ [unknownKeyDoc]) "..."
        ]
      ]


--------------------------------------------------------------------------------
-- ConfigInvalidSyntaxFound

renderConfigInvalidSyntaxFound :: FileValueOrigin -> Doc Ann
renderConfigInvalidSyntaxFound origin =
  let filepathDoc = getFileFromOrigin origin
  in
    foundError3
      "file resolver"
      (vsep
        [ reflow "Found a configuration file with unsupported syntax"
        , mempty
        , reflow "In the configuration spec file"
        , mempty
        , indent 2 $ renderKeyPathBody ["etc/files", "path"] $ newlineBody $ vsep
          ["- ...", annotate Error $ pointed ("-" <+> filepathDoc), "- ..."]
        ]
      )
      [ reflow "Make sure the contents of the configuration file" <+> filepathDoc <+> reflow
          "are valid"
      ]


--------------------------------------------------------------------------------
-- SubConfigEntryExpected

subConfigEntryExpectedBody :: FileValueOrigin -> [Doc Ann] -> JSON.Value -> Doc Ann
subConfigEntryExpectedBody origin keyPath jsonVal =
  vsep
    [ reflow
        "There is a mistmach between a configuration file entry and the spec specified in the configuration spec file"
    , mempty
    , "In the configuration file" <+> renderFileOrigin origin
    , mempty
    , indent 2 $
      renderKeyPathBody keyPath $
      newlineBody $ annotate Current (pointed (renderJsonValue jsonVal))
    , mempty
    , "The" <+>
      annotate Current "current entry" <+>
      "does not match the definition in the configuration spec"
    ]

renderSubConfigEntryExpected :: FileValueOrigin -> [Text] -> JSON.Value -> Doc Ann
renderSubConfigEntryExpected origin keyPath jsonVal = foundError3
  "file resolver"
  (subConfigEntryExpectedBody origin (map pretty keyPath) jsonVal)
  [ reflow "Make sure the entry metadata is contained in an \"etc/spec\" entry"
  , reflow "Change the entry found in the configuration file"
    <+> renderFileOrigin1 origin
    <+> reflow "to match the definition found in the spec"
  ]

--------------------------------------------------------------------------------

instance HumanErrorMessage FileResolverError where
  humanErrorMessage err =
    case err of
      ConfigSpecFilesEntryMissing siblingKeys ->
        renderConfigSpecFilesEntryMissingBody siblingKeys

      ConfigSpecFilesPathsEntryIsEmpty ->
        renderConfigSpecFilesPathsEntryIsEmpty

      UnsupportedFileExtensionGiven path ext ->
        renderUnsupportedFileExtensionGiven path ext

      ConfigFileValueTypeMismatch origin specFilePath keyPath cvType jsonVal ->
        renderConfigFileValueTypeMismatchFound origin specFilePath keyPath cvType jsonVal

      ConfigFileNotPresent path ->
        renderConfigFileNotPresent path

      UnknownConfigKeyFound origin keyPath keyName _siblingKeys ->
        renderUnknownConfigKeyFound origin keyPath keyName

      ConfigInvalidSyntaxFound origin ->
        renderConfigInvalidSyntaxFound origin

      SubConfigEntryExpected origin keyPath jsonVal ->
        renderSubConfigEntryExpected origin keyPath jsonVal