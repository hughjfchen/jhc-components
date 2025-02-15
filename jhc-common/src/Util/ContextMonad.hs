module Util.ContextMonad where

import Control.Monad.Trans.Except
import Control.Applicative

class Monad m => ContextMonad m where
    type ContextOf m
    withContext :: ContextOf m -> m a -> m a

newtype ContextEither a = ContextEither (Either [String] a)
    deriving(Functor, Applicative)

runContextEither (ContextEither a) = a

instance MonadFail ContextEither where
    fail s = ContextEither (Left [s])

instance Monad ContextEither where
    ContextEither x >>= y = case x of
        Left ss -> ContextEither (Left ss)
        Right v -> y v
    return x = ContextEither (Right x)

instance ContextMonad ContextEither where
    type ContextOf ContextEither = String
    withContext s (ContextEither (Left ss)) = ContextEither (Left (s:ss))
    withContext _ r = r

runSimpleContextMonad :: ContextEither a -> a
runSimpleContextMonad (ContextEither (Left ss)) = error $ unlines ss
runSimpleContextMonad (ContextEither (Right x)) = x
