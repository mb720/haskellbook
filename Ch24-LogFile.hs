{-# LANGUAGE OverloadedStrings, QuasiQuotes #-}

module LogFile where

import Control.Applicative
import Data.ByteString hiding (foldr, count)
import Data.Map (Map)
import qualified Data.Map as M
import Data.Monoid ((<>))
import Test.Hspec
import Text.Printf (printf)
import Text.RawString.QQ
import Text.Trifecta

logEx :: ByteString
logEx = [r|
-- wheee a comment

# 2025-02-05
08:00 Breakfast
09:00 Sanitizing moisture collector
11:00 Exercising in high-grav gym
12:00 Lunch
13:00 Programming
17:00 Commuting home in rover
17:30 R&R
19:00 Dinner
21:00 Shower
21:15 Read
22:00 Sleep

# 2025-02-07 -- dates not nececessarily sequential
08:00 Breakfast -- should I try skippin bfast?
09:00 Bumped head, passed out
13:36 Wake up, headache
13:37 Go to medbay
13:40 Patch self up
13:45 Commute home for rest
14:15 Read
21:00 Dinner
21:15 Read
22:00 Sleep
|]

type Hours = Integer
type Minutes = Integer
type Day = Integer
type Month = Integer
type Year = Integer
type Activity = String

newtype NewTime = NewTime Integer deriving (Eq, Ord)
data Date = Date Year Month Day deriving (Eq, Show)
data Time = Time Hours Minutes deriving (Eq, Show)
data Entry = Entry NewTime Activity deriving (Eq, Show)
data Section = Section Date (Map NewTime Activity) deriving (Eq, Show)
type Log = Map Date (Map NewTime Activity)

miniLog :: ByteString
miniLog = [r|
# 2025-02-05
08:00 Breakfast -- nice
08:30 Shower -- the water was freezing!  
|]

parseActivity :: Parser String
parseActivity = do
  a <- try
       (manyTill (noneOf "\n") comment)
                <|> try (manyTill anyChar newline)
                <|> many anyChar

  skipOptional skipLine
  return a

comment :: Parser String
comment = try (someSpace >> string "--")
          <|> string "--"

skipLine :: Parser ()
skipLine = skipMany (noneOf "\n") >> skipOptional (char '\n') >> return ()

parseDate :: Parser Date
parseDate = do
  _ <- string "# "
  year <- count 4 digit
  _ <- char '-'
  month <- count 2 digit
  _ <- char '-'
  day <- count 2 digit
  return $ Date (read year) (read month) (read day)

parseEntry :: Parser Entry
parseEntry = do
  h <- count 2 digit
  _ <- char ':'
  m <- count 2 digit
  _ <- char ' '
  e <- parseActivity
  let hm = read h * 60
      mm = read m
  return $ Entry (NewTime (hm + mm)) e

skipComment :: Parser ()
skipComment = skipOptional (comment >> skipLine)

parseSection :: Parser Section
parseSection = do
  skipMany (noneOf "#")
  d <- parseDate
  skipComment
  whiteSpace
  entries <- some parseEntry
  return $ Section d (M.fromList $ readEntry <$> entries)

readEntry :: Entry -> (NewTime, Activity)
readEntry (Entry t a) = (t, a)

readSection :: Section -> (Date, Map NewTime Activity)
readSection (Section d a) = (d, a)

-- parseByteString (some parseSection) mempty logEx

parseLog :: Parser Log
parseLog = do
  s <- some parseSection
  return $ M.fromList (readSection <$> s)

-- parseByteString parseLog mempty logEx

instance Show NewTime where
  show (NewTime rawmin) = let
    h = quot rawmin 60
    m = rem rawmin 60
    in printf "%02d" h ++ ":" ++ printf "%02d" (abs m)

instance Num NewTime where
    (NewTime m) + (NewTime m') = NewTime (m + m')
    (NewTime m) - (NewTime m') = NewTime (m - m')
    fromInteger = NewTime
    (NewTime m) * (NewTime m') = NewTime (m * m')
    abs (NewTime m) = NewTime (abs m)
    signum (NewTime m) = NewTime (signum m)

instance Ord Date where
  Date y m d `compare` Date y' m' d' =
    compare y y' <> compare m m' <> compare d d'

instance Ord Time where
  Time h m `compare` Time h' m' =
    compare h h' <> compare m m'


maybeSuccess :: Result a -> Maybe a
maybeSuccess (Success a) = Just a
maybeSuccess _ = Nothing

main :: IO ()
main = hspec $ do

         describe "Entry Parsing" $ do
               it "can parse a simple Entry" $ do
                 let m = parseByteString parseEntry
                         mempty "12:30 Lunch"
                     r' = maybeSuccess m
                 print m
                 r' `shouldBe` Just (Entry (NewTime 750) "Lunch")

               it "can parse an Entry with comments -- no space" $ do
                 let m = parseByteString parseEntry
                         mempty "12:30 Lunch--felt full"
                     r' = maybeSuccess m
                 print m
                 r' `shouldBe` Just (Entry (NewTime 750) "Lunch")

               it "can parse an Entry with comments -- one space" $ do
                 let m = parseByteString parseEntry
                         mempty "12:30 Lunch --felt full"
                     r' = maybeSuccess m
                 print m
                 r' `shouldBe` Just (Entry (NewTime 750) "Lunch")

               it "can parse an Entry with comments -- many spaces" $ do
                 let m = parseByteString parseEntry
                         mempty "12:30 Lunch   --felt full\n"
                     r' = maybeSuccess m
                 print m
                 r' `shouldBe` Just (Entry (NewTime 750) "Lunch")

         describe "Section Parsing" $ do
               it "can parse a simple section" $ do
                 let m = parseByteString parseSection
                         mempty miniLog
                     r' = maybeSuccess m
                 print m
                 r' `shouldBe` Just (Section (Date 2025 2 5)
                                    (M.fromList [(NewTime 480,"Breakfast")
                                                ,(NewTime 510,"Shower")]))

         -- describe "Log Parsing" $ do
         --       it "can parse a full log" $ do
         --         let m = parseByteString parseLog
         --                 mempty logEx
         --             r' = maybeSuccess m
         --         print m
         --         r' `shouldBe`
         --            Just (M.fromList [(Date 2025 2 5, M.fromList [(NewTime 0,"Breakfast"),(NewTime 110,"Exercising in high-grav gym"),(NewTime 10,"Programming"),(NewTime 1730,"R&R"),(NewTime 210,"Shower"),(NewTime 220,"Sleep")]),(Date 2025 2 7, M.fromList [(NewTime 80,"Breakfast"),(NewTime 90,"Bumped head, passed out"),(NewTime 1337,"Go to medbay"),(NewTime 1345,"Commute home for rest"),(NewTime 210,"Dinner"),(NewTime 220,"Sleep")])])

--x = M.fromList [(Date 2012 2 3, M.fromList [(NewTime 8 0, "breakfast"),(NewTime 9 30, "rest")])]

         describe "Date operations" $ do
               it "can add dates" $ do
                 let m = NewTime 30 + NewTime 130
                 print m
                 m `shouldBe` NewTime 160

               it "can subtract dates" $ do
                 let m = NewTime 30 - NewTime 130
                 print m
                 m `shouldBe` NewTime (-100)

               it "creates fromInteger Date" $ do
                 let m = 61
                 print m
                 m `shouldBe` NewTime 61

               it "Multiplies (kinda)" $ do
                 let m = NewTime 30 * 2
                 print m
                 m `shouldBe` NewTime 60
