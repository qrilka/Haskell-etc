{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoImplicitPrelude #-}
module Etc.Resolver.Cli.PlainTest where

import           Protolude

import           Test.Tasty                 (TestTree, testGroup)
import           Test.Tasty.HUnit           (assertBool, assertFailure, testCase)

import qualified Data.Set as Set

import           Etc

option_tests :: TestTree
option_tests =
  testGroup "option input"
  [
    testCase "entry accepts short" $ do
      let
        input =
          mconcat
            [
              "{ \"etc/entries\": {"
            , "    \"greeting\": {"
            , "      \"etc/spec\": {"
            , "        \"cli\": {"
            , "          \"input\": \"option\""
            , "        , \"short\": \"g\""
            , "        , \"long\": \"greeting\""
            , "        , \"type\": \"string\""
            , "}}}}}"
            ]
      (spec :: ConfigSpec ()) <- parseConfigSpec input
      config <- resolvePlainCliPure spec "program" ["-g", "hello cli"]

      case getAllConfigSources ["greeting"] config of
        Nothing ->
          assertFailure ("expecting to get entries for greeting\n"
                         <> show config)
        Just set -> do
          assertBool ("expecting to see entry from env; got " <> show set)
                     (Set.member (Cli "hello cli") set)

  , testCase "entry accepts long" $ do
      let
        input =
          mconcat
            [
              "{ \"etc/entries\": {"
            , "    \"greeting\": {"
            , "      \"etc/spec\": {"
            , "        \"cli\": {"
            , "          \"input\": \"option\""
            , "        , \"short\": \"g\""
            , "        , \"long\": \"greeting\""
            , "        , \"type\": \"string\""
            , "}}}}}"
            ]
      (spec :: ConfigSpec ()) <- parseConfigSpec input
      config <- resolvePlainCliPure spec "program" ["--greeting", "hello cli"]

      case getAllConfigSources ["greeting"] config of
        Nothing ->
          assertFailure ("expecting to get entries for greeting\n"
                         <> show config)
        Just set -> do
          assertBool ("expecting to see entry from env; got " <> show set)
                     (Set.member (Cli "hello cli") set)

  , testCase "entry gets validated with a type" $ do
      let
        input =
          mconcat
            [
              "{ \"etc/entries\": {"
            , "    \"greeting\": {"
            , "      \"etc/spec\": {"
            , "        \"cli\": {"
            , "          \"input\": \"option\""
            , "        , \"short\": \"g\""
            , "        , \"long\": \"greeting\""
            , "        , \"type\": \"number\""
            , "}}}}}"
            ]
      (spec :: ConfigSpec ()) <- parseConfigSpec input

      case resolvePlainCliPure spec "program" ["--greeting", "hello cli"] of
        Left err ->
          case fromException err of
            Just (CliEvalExited {}) ->
              return ()

            _ ->
              assertFailure ("Expecting type validation to work on cli; got "
                             <> show err)


        Right _ ->
          assertFailure "Expecting type validation to work on cli"

  , testCase "entry with required false does not barf" $ do
      let
        input =
          mconcat
            [
              "{ \"etc/entries\": {"
            , "    \"greeting\": {"
            , "      \"etc/spec\": {"
            , "        \"cli\": {"
            , "          \"input\": \"option\""
            , "        , \"short\": \"g\""
            , "        , \"long\": \"greeting\""
            , "        , \"type\": \"string\""
            , "        , \"required\": false"
            , "}}}}}"
            ]
      (spec :: ConfigSpec ()) <- parseConfigSpec input
      config <- resolvePlainCliPure spec "program" []

      case getConfigValue ["greeting"] config of
        Just set -> do
          assertFailure ("expecting to have no entry for greeting; got\n"
                         <> show set)

        (_ :: Maybe ()) ->
          return ()

  , testCase "entry with required fails when option not given" $ do
      let
        input =
          mconcat
            [
              "{ \"etc/entries\": {"
            , "    \"greeting\": {"
            , "      \"etc/spec\": {"
            , "        \"cli\": {"
            , "          \"input\": \"option\""
            , "        , \"short\": \"g\""
            , "        , \"long\": \"greeting\""
            , "        , \"type\": \"string\""
            , "        , \"required\": true"
            , "}}}}}"
            ]
      (spec :: ConfigSpec ()) <- parseConfigSpec input
      case resolvePlainCliPure spec "program" [] of
        Left err ->
          case fromException err of
            Just (CliEvalExited {}) ->
              return ()

            _ ->
              assertFailure ("Expecting required validation to work on cli; got "
                             <> show err)

        Right _ ->
          assertFailure "Expecting required option to fail cli resolving"

  ]

argument_tests :: TestTree
argument_tests =
  testGroup "argument input"
  [
    testCase "entry gets validated with a type" $ do
      let
        input =
          mconcat
            [
              "{ \"etc/entries\": {"
            , "    \"greeting\": {"
            , "      \"etc/spec\": {"
            , "        \"cli\": {"
            , "          \"input\": \"argument\""
            , "        , \"type\": \"number\""
            , "        , \"metavar\": \"GREETING\""
            , "}}}}}"
            ]
      (spec :: ConfigSpec ()) <- parseConfigSpec input

      case resolvePlainCliPure spec "program" ["hello cli"] of
        Left err ->
          case fromException err of
            Just (CliEvalExited {}) ->
              return ()

            _ ->
              assertFailure ("Expecting type validation to work on cli; got "
                             <> show err)

        Right _ ->
          assertFailure "Expecting type validation to work on cli"

  , testCase "entry with required false does not barf" $ do
      let
        input =
          mconcat
            [
              "{ \"etc/entries\": {"
            , "    \"greeting\": {"
            , "      \"etc/spec\": {"
            , "        \"cli\": {"
            , "          \"input\": \"argument\""
            , "        , \"type\": \"string\""
            , "        , \"metavar\": \"GREETING\""
            , "        , \"required\": false"
            , "}}}}}"
            ]
      (spec :: ConfigSpec ()) <- parseConfigSpec input
      config <- resolvePlainCliPure spec "program" []

      case getConfigValue ["greeting"] config of
        (Nothing :: Maybe ()) ->
          return ()

        Just set -> do
          assertFailure ("expecting to have no entry for greeting; got\n"
                         <> show set)

  , testCase "entry with required fails when argument not given" $ do
      let
        input =
          mconcat
            [
              "{ \"etc/entries\": {"
            , "    \"greeting\": {"
            , "      \"etc/spec\": {"
            , "        \"cli\": {"
            , "          \"input\": \"argument\""
            , "        , \"type\": \"string\""
            , "        , \"metavar\": \"GREETING\""
            , "        , \"required\": true"
            , "}}}}}"
            ]
      (spec :: ConfigSpec ()) <- parseConfigSpec input
      case resolvePlainCliPure spec "program" [] of
        Left err ->
          case fromException err of
            Just (CliEvalExited {}) ->
              return ()

            _ ->
              assertFailure ("Expecting required validation to work on cli; got "
                             <> show err)

        Right _ ->
          assertFailure "Expecting required argument to fail cli resolving"


  ]

tests :: TestTree
tests =
  testGroup "plain"
  [
    option_tests
  , argument_tests
  ]
