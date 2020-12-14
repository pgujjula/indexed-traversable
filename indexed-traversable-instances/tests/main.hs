{-# LANGUAGE CPP                 #-}
{-# LANGUAGE RankNTypes          #-}
{-# LANGUAGE ScopedTypeVariables #-}
module Main (main) where

import Control.Applicative   (Const (..))
import Data.Foldable         (toList)
import Data.Functor.Identity (Identity (..))
import Data.Monoid           (Endo (..), Monoid (..))
import Test.QuickCheck
       (Arbitrary, CoArbitrary, Fun, Function, Property, applyFun, (===))
import Test.QuickCheck.Poly  (A, B)
import Test.Tasty            (TestTree, defaultMain, testGroup)
import Test.Tasty.QuickCheck (testProperty)

import qualified Data.HashMap.Lazy as HM
import qualified Data.Map          as Map
import qualified Data.Sequence     as Seq
import qualified Data.Vector       as V

#if MIN_VERSION_containers(0,6,3)
-- traverseWithKey and Foldable broken before
import qualified Data.IntMap as IntMap
#endif

import Data.Functor.WithIndex.Instances ()
import Test.QuickCheck.Instances ()

import Data.Foldable.WithIndex
import Data.Functor.WithIndex
import Data.Traversable.WithIndex

#if MIN_VERSION_base(4,7,0)
import Data.Typeable (Typeable, typeRep)
#else
import Data.Typeable (TypeRep, Typeable1, typeOf1)

#define Typeable Typeable1

typeRep :: forall f i. Typeable1 f => Tests i f -> TypeRep
typeRep _ = typeOf1 (undefined :: f Int)
#endif

-------------------------------------------------------------------------------
-- Main
-------------------------------------------------------------------------------

main :: IO ()
main = defaultMain $ testGroup "tests"
    [ battery $ mkT $ zipWith const [0 ..]
    , battery $ mkT (Map.keys :: forall a. Map.Map I a -> [I])
    , battery $ mkT (HM.keys :: forall a. HM.HashMap I a -> [I])
    , battery $ mkT (zipWith const [0 ..] . toList :: forall a. Seq.Seq a -> [Int])
    , battery $ mkT $ zipWith const [0 ..] . V.toList
#if MIN_VERSION_containers(0,6,3)
    , battery $ mkT IntMap.keys
#endif
    ]

-------------------------------------------------------------------------------
-- Test battery
-------------------------------------------------------------------------------

data Tests i f = T
    { indices :: forall a. f a -> [i]
    }

mkT :: FunctorWithIndex i f => (forall a. f a -> [i]) -> Tests i f
mkT = T

type I = Int

battery
    :: forall f i. (Typeable f, TraversableWithIndex i f
        , Arbitrary (f A), Show (f A)
        , Show (f B), Eq (f B)
        , Function i, CoArbitrary i, Show i, Eq i
        )
    => Tests i f
    -> TestTree
battery t = testGroup name
    [ testProperty "imapDefault" $
        let prop :: Fun (i, A) B -> f A -> Property
            prop f' xs = imap f xs === imapDefault f xs where
                f i a = applyFun f' (i, a)

        in prop

    , testProperty "ifoldMapDefault" $
        let prop :: Fun (i, A) [B] -> f A -> Property
            prop f' xs = ifoldMap f xs === ifoldMapDefault f xs where
                f i a = applyFun f' (i, a)

        in prop

    , testProperty "ifoldrDefault" $
        let prop :: Fun (i, A, B) B -> B -> f A -> Property
            prop f' b xs = ifoldr f b xs === ifoldrDefault f b xs where
                f i x y = applyFun f' (i, x, y)

        in prop

    , testProperty "toList" $
        let prop :: f A -> Property
            prop xs = toList xs === map snd (itoList xs)

        in prop

    , testProperty "indices" $
        let prop :: f A -> Property
            prop xs = indices t xs === map fst (itoList xs)

        in prop
    ]
  where
    name = show (typeRep t)

-------------------------------------------------------------------------------
-- Defaults
-------------------------------------------------------------------------------

ifoldrDefault :: FoldableWithIndex i f => (i -> a -> b -> b) -> b -> f a -> b
ifoldrDefault f z t = appEndo (ifoldMap (\i -> Endo . f i) t) z
