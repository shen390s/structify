-- | Test suite entry point
module Main (main) where

import Test.Hspec

main :: IO ()
main = hspec $ do
  describe "Structify" $ do
    it "placeholder test" $ do
      True `shouldBe` True
