{-# LANGUAGE OverloadedStrings #-}
module UI where

import Control.Monad (forever, void)
import Control.Monad.IO.Class (liftIO)
import Control.Concurrent (threadDelay, forkIO)
import Data.Maybe (fromMaybe)

import Maze

import Brick
  ( App(..), AttrMap, BrickEvent(..), EventM, Next, Widget
  , customMain, neverShowCursor
  , continue, halt
  , hLimit, vLimit, vBox, hBox
  , padRight, padLeft, padTop, padAll, Padding(..)
  , withBorderStyle
  , str
  , attrMap, withAttr, emptyWidget, AttrName, on, fg
  , (<+>)
  )
import Brick.BChan (newBChan, writeBChan)
import qualified Brick.Widgets.Border as B
import qualified Brick.Widgets.Border.Style as BS
import qualified Brick.Widgets.Center as C
import Control.Lens ((^.))
import qualified Graphics.Vty as V
import Data.Sequence (Seq)
import qualified Data.Sequence as S
import Linear.V2 (V2(..))

-- Types

-- | Ticks mark passing of time
--
-- This is our custom event that will be constantly fed into the app.
data Tick = Tick

-- | Named resources

data Cell = Player1 | Player2 | Bullet | Solid | Normal | Grass | Empty

-- App definition
type Name = ()
app :: App Game Tick Name
app = App { appDraw = drawUI
          , appChooseCursor = neverShowCursor
          , appHandleEvent = handleEvent
          , appStartEvent = return
          , appAttrMap = const theMap
          }

main :: IO () -- 程序的入口
main = do
  chan <- newBChan 10
  forkIO $ forever $ do
    writeBChan chan Tick
    threadDelay 100000 -- decides how fast your game moves
  g <- initGame
  let builder = V.mkVty V.defaultConfig
  initialVty <- builder
  void $ customMain initialVty builder (Just chan) app g

-- Handling events

handleEvent :: Game -> BrickEvent Name Tick -> EventM Name (Next Game)
-- handleEvent g (AppEvent Tick)                       = continue $ step g
handleEvent g (VtyEvent (V.EvKey V.KUp []))         = continue $ turn1 North g
handleEvent g (VtyEvent (V.EvKey V.KDown []))       = continue $ turn1 South g
handleEvent g (VtyEvent (V.EvKey V.KRight []))      = continue $ turn1 East g
handleEvent g (VtyEvent (V.EvKey V.KLeft []))       = continue $ turn1 West g
handleEvent g (VtyEvent (V.EvKey (V.KChar 'w') [])) = continue $ turn2 North g
handleEvent g (VtyEvent (V.EvKey (V.KChar 's') [])) = continue $ turn2 South g
handleEvent g (VtyEvent (V.EvKey (V.KChar 'd') [])) = continue $ turn2 East g
handleEvent g (VtyEvent (V.EvKey (V.KChar 'a') [])) = continue $ turn2 West g
-- handleEvent g (VtyEvent (V.EvKey (V.KChar 'r') [])) = liftIO (initGame) >>= continue
handleEvent g (VtyEvent (V.EvKey (V.KChar 'q') [])) = halt g
handleEvent g (VtyEvent (V.EvKey V.KEsc []))        = halt g
handleEvent g _                                     = continue g

-- Drawing

drawUI :: Game -> [Widget Name]
drawUI g =
  [ C.center $ padRight (Pad 2) (drawStats g) <+> drawGrid g ]

drawStats :: Game -> Widget Name
drawStats g = hLimit 15
  $ vBox [ drawScore (g ^. score1)
         , drawScore (g ^. score2)
         , padTop (Pad 2) $ drawGameOver (g ^. dead)
         ]

drawScore :: Int -> Widget Name
drawScore n = withBorderStyle BS.unicodeBold
  $ B.borderWithLabel (str "Score")
  $ C.hCenter
  $ padAll 1
  $ str $ show n

drawGameOver :: Bool -> Widget Name
drawGameOver dead =
  if dead
     then withAttr gameOverAttr $ C.hCenter $ str "GAME OVER"
     else emptyWidget

drawGrid :: Game -> Widget Name
drawGrid g = withBorderStyle BS.unicodeBold
  $ B.borderWithLabel (str "Maze")
  $ vBox rows
  where
    rows         = [hBox $ cellsInRow r | r <- [height-1,height-2..0]]
    cellsInRow y = [drawCoord (V2 x y) | x <- [0..width-1]]
    drawCoord    = drawCell . cellAt
    cellAt c
      | c == (g ^. player1) = Player1
      | c == (g ^. player2) = Player2
      | c == g ^. bullet      = Bullet
      | c `elem` g ^. solid   = Solid
      | c `elem` g ^. normal  = Normal
      | c `elem` g ^. grass   = Grass
      | otherwise             = Empty

drawCell :: Cell -> Widget Name
drawCell Player1 = withAttr player1Attr cw 
drawCell Player2 = withAttr player2Attr cw 
drawCell Bullet = withAttr bulletAttr cw 
drawCell Normal  = withAttr normalAttr cw 
drawCell Grass   = withAttr grassAttr cw 
drawCell Solid   = withAttr solidAttr cw 
drawCell Empty   = withAttr emptyAttr cw

cw :: Widget Name
cw = str "  "

-- color for each item
theMap :: AttrMap
theMap = attrMap V.defAttr
  [ (bulletAttr, V.yellow `on` V.yellow)
  , (normalAttr, V.brightMagenta `on` V.brightMagenta)
  , (grassAttr, V.brightGreen `on` V.brightGreen)
  , (solidAttr, V.brightBlack `on` V.brightBlack)
  , (player1Attr, V.cyan `on` V.cyan)
  , (player2Attr, V.red `on` V.red)
  , (emptyAttr, V.white `on` V.white)
  , (gameOverAttr, fg V.red `V.withStyle` V.bold)
  ]

gameOverAttr :: AttrName
gameOverAttr = "gameOver"

bulletAttr, normalAttr, grassAttr, solidAttr, player1Attr, player2Attr, emptyAttr :: AttrName
bulletAttr = "bulletAttr"
normalAttr  = "normalAttr"
grassAttr   = "grassAttr"
solidAttr   = "solidAttr"
player1Attr = "player1Attr"
player2Attr = "player2Attr"
emptyAttr   = "emptyAttr"
