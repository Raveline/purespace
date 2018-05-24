-- Base.hs ---

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

module PureSpace.Common.Game.Base
  (
    module PureSpace.Common.Game.Types,
    Base (..),
    BaseType (..),
    HasIncome (..),
    HasIsHeadquarter (..),
    HasBase (..),
    HasBaseType (..),
    Income,
    IsHeadquarter,
  )
where


import           PureSpace.Common.Game.Types
import           PureSpace.Common.Lens       (Lens', lens)

-- | An amount of cash received regularly
type Income        = Integer
-- | Headquarters are vital targets; if no headerquarter remains,
-- a player has lost.
type IsHeadquarter = Bool


-- | Base of a player, providers of income and potentially
-- main target of an opponent
data Base     = Base BaseType Team Income Health Position     deriving (Eq, Ord, Show)
data BaseType = BaseType MaxHealth IsHeadquarter Width Height deriving (Eq, Ord, Show)

class HasBase b where
  base :: Lens' b Base

class HasBaseType b where
  baseType :: Lens' b BaseType

class HasIncome i where
  income :: Lens' i Income

class HasIsHeadquarter i where
  isHeadquarter :: Lens' i IsHeadquarter

instance HasBase Base where
  base = id

instance HasBaseType Base where
 baseType =
    let f (Base a _ _ _ _)   = a
        g (Base _ b c d e) a = Base a b c d e
    in lens f g

instance HasTeam Base where
  team =
    let f (Base _ b _ _ _)   = b
        g (Base a _ c d e) b = Base a b c d e
    in lens f g

instance HasIncome Base where
  income =
    let f (Base _ _ c _ _)   = c
        g (Base a b _ d e) c = Base a b c d e
    in lens f g

instance HasHealth Base where
  health =
    let f (Base _ _ _ d _)   = d
        g (Base a b c _ e) d = Base a b c d e
    in lens f g

instance HasPosition Base where
  position =
    let f (Base _ _ _ _ e)   = e
        g (Base a b c d _) e = Base a b c d e
    in lens f g

instance HasMaxHealth Base where
  maxHealth = baseType . maxHealth

instance HasIsHeadquarter Base where
  isHeadquarter = baseType . isHeadquarter

instance HasWidth Base where
  width = baseType . width

instance HasHeight Base where
  height = baseType . height

instance HasBaseType BaseType where
  baseType = id

instance HasMaxHealth BaseType where
  maxHealth =
    let f (BaseType a _ _ _)   = a
        g (BaseType _ b c d) a = BaseType a b c d
    in lens f g

instance HasIsHeadquarter BaseType where
  isHeadquarter =
    let f (BaseType _ b _ _)   = b
        g (BaseType a _ c d) b = BaseType a b c d
    in lens f g

instance HasWidth BaseType where
  width =
    let f (BaseType _ _ c _)   = c
        g (BaseType a b _ d) c = BaseType a b c d
    in lens f g

instance HasHeight BaseType where
  height =
    let f (BaseType _ _ _ d)   = d
        g (BaseType a b c _) d = BaseType a b c d
    in lens f g