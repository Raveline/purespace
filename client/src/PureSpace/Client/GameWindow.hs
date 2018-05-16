-- GameWindow.hs ---

-- Copyright (C) 2018 Hussein Ait-Lahcen

-- Author: Hussein Ait-Lahcen <hussein.aitlahcen@gmail.com>

-- This program is free software; you can redistribute it and/or
-- modify it under the terms of the GNU General Public License
-- as published by the Free Software Foundation; either version 3
-- of the License, or (at your option) any later version.

-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.

-- You should have received a copy of the GNU General Public License
-- along with this program. If not, see <http://www.gnu.org/licenses/>.

{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeSynonymInstances  #-}

module PureSpace.Client.GameWindow
  (
    runApp
  )
  where

import           Codec.Picture
import           Data.List
import           Data.Vector.Storable           (fromList, unsafeWith)
import           Foreign.Storable               (Storable (..), sizeOf)
import qualified Graphics.GLUtil                as U
import           Graphics.UI.GLUT               as GLUT
import qualified Linear                         as L
import           PureSpace.Client.Game
import           PureSpace.Client.ShaderProgram
import           PureSpace.Client.Sprites
import           PureSpace.Common.Lens

runApp :: IO ()
runApp = do
  result <- runGame (GameApp createGameWindow) appConfig appState
  case result of
    Left message -> print (message :: GameError)
    Right _      -> putStrLn "Unseen string"
  where
    appState  = GameState
    appConfig = GameConfig
{-
############################
Everything under this line is complete garbage atm
############################
-}

data DrawableSprite = DrawableSprite Sprite (BufferObject, VertexArrayObject) deriving Show

createGameWindow :: (MonadIO m, MonadError e m, AsAssetError e, AsShaderError e, AsShaderProgramError e) => m ()
createGameWindow = do
  initialContextVersion $= (3, 3)
  atlas          <- loadAtlas
  (_, _)         <- getArgsAndInitialize
  window         <- createWindow "PureSpace"
  (text, sprite, program) <- initContext atlas
  liftIO $ print sprite
  displayCallback $= display program text sprite
  idleCallback    $= Just (postRedisplay (Just window))
  mainLoop

initContext :: (MonadIO m, MonadError e m, AsShaderError e, AsShaderProgramError e) => SpriteAtlas -> m (TextureObject, DrawableSprite, Program)
initContext (SpriteAtlas image sprites) = do
  liftIO $ putStrLn "initialize"
  shaderProgram <- loadGameShaderProgram
  initialDisplayMode          $= [DoubleBuffered]
  blend                       $= Enabled
  sampleAlphaToOne            $= Enabled
  sampleAlphaToCoverage       $= Enabled
  depthBounds                 $= Nothing
  depthFunc                   $= Nothing
  texObject <- genObjectName
  textureBinding  Texture2D   $= Just texObject
  textureWrapMode Texture2D S $= (Mirrored, ClampToBorder)
  textureWrapMode Texture2D T $= (Mirrored, ClampToBorder)
  textureFilter   Texture2D   $= ((Linear', Nothing), Linear')
  (Right (ImageRGBA8 (Image width height pixels))) <- liftIO $ readImage image
  liftIO $ unsafeWith pixels $ \ptr ->
    texImage2D
      Texture2D
      NoProxy
      0
      RGBA8
      (TextureSize2D (fromIntegral width) (fromIntegral height))
      0
      (PixelData RGBA UnsignedByte ptr)
  liftIO $ generateMipmap' Texture2D
  let (Just s@(Sprite _ x y w h)) = Data.List.find (\(Sprite name _ _ _ _) -> name == "playerShip2_blue.png") sprites
  vbo <- createVBO $ spriteVertices (normalizeUV x width) (normalizeUV y height) (normalizeUV w width) (normalizeUV h height)
  pure (texObject, DrawableSprite s vbo, shaderProgram)
  where
    normalizeUV a b = fromIntegral a / fromIntegral b

spriteVertices ::GLfloat -> GLfloat -> GLfloat -> GLfloat -> [GLfloat]
spriteVertices x y w h =
      [
        -w/2,  h/2, x, y,
         w/2,  h/2, x + w, y,
         w/2, -h/2, x + w, y + h,

        -w/2,  h/2, x, y,
         w/2, -h/2, x + w, y + h,
        -w/2, -h/2, x, y + h
      ]

createVBO :: MonadIO m => [GLfloat] -> m (BufferObject, VertexArrayObject)
createVBO vertices = do
  vertexArray  <- genObjectName
  vertexBuffer <- genObjectName
  bindBuffer ArrayBuffer $= Just vertexBuffer
  let vector = fromList vertices
  liftIO $ unsafeWith vector $ \ptr ->
    bufferData ArrayBuffer $= (bufferSize, ptr, StaticDraw)
  bindVertexArrayObject                  $= Just vertexArray
  vertexAttribArray   (AttribLocation 0) $= Enabled
  vertexAttribPointer (AttribLocation 0) $= (ToFloat, VertexArrayDescriptor 4 Float 0 U.offset0)
  bindBuffer ArrayBuffer                 $= Nothing
  bindVertexArrayObject                  $= Nothing
  pure (vertexBuffer, vertexArray)
  where
    bufferSize = toEnum $ length vertices * sizeOf (head vertices)

-- Almost fully stateless rendering
display :: Program -> TextureObject -> DrawableSprite -> DisplayCallback
display program text (DrawableSprite _ (_, vao)) = do
  Size width height <- GLUT.get windowSize
  clear [ColorBuffer, DepthBuffer]
  currentProgram           $= Just program
  textureBinding Texture2D $= Just text
  uniformMatrix (projectionMatrix width height)       "mProjection"
  uniformMatrix (identity & L.translation %~ (+ 0.3)) "mModelView"
  bindVertexArrayObject $= Just vao
  drawArrays Triangles 0 6
  bindVertexArrayObject $= Nothing
  currentProgram        $= Nothing
  swapBuffers
  where
    identity = L.identity :: L.M44 GLfloat

    uniformMatrix mat n = GLUT.get $ uniformLocation program n >>= U.asUniform mat

    projectionMatrix :: Integral a => a -> a -> L.M44 GLfloat
    projectionMatrix w h
      | w > h     = L.ortho (-visibleArea*aspectRatio) (visibleArea*aspectRatio) (-visibleArea)             visibleArea               (-1) 1
      | otherwise = L.ortho (-visibleArea)             visibleArea               (-visibleArea/aspectRatio) (visibleArea/aspectRatio) (-1) 1
      where
        visibleArea = 1
        aspectRatio = fromIntegral w / fromIntegral h
