{- Generated by DrIFT (Automatic class derivations for Haskell) -}
{-# LINE 1 "src/FrontEnd/Representation.hs" #-}
module FrontEnd.Representation(
    Type(..),
    Tyvar(..),
    tyvar,
    Tycon(..),
    fn,
    Pred(..),
    Qual(..),
    Class,
    tForAll,
    tExists,
    MetaVarType(..),
    prettyPrintType,
    fromTAp,
    fromTArrow,
    tassocToAp,
    MetaVar(..),
    tTTuple,
    tTTuple',
    tList,
    tArrow,
    tAp
    )where

import Control.Monad.Identity
import Data.IORef

import Data.Binary
import Doc.DocLike
import Doc.PPrint
import FrontEnd.Tc.Kind
import Name.Name
import Name.Names
import Name.VConsts
import Support.CanType
import Support.Unparse
import Util.VarName

-- Types

data MetaVarType = Tau | Rho | Sigma
             deriving(Eq,Ord)
    {-! derive: Binary !-}

data Type  = TVar     { typeVar :: !Tyvar }
           | TCon     { typeCon :: !Tycon }
           | TAp      Type Type
           | TArrow   Type Type
           | TForAll  { typeArgs :: [Tyvar], typeBody :: (Qual Type) }
           | TExists  { typeArgs :: [Tyvar], typeBody :: (Qual Type) }
           | TMetaVar { metaVar :: MetaVar }
           | TAssoc   { typeCon :: !Tycon, typeClassArgs :: [Type], typeExtraArgs :: [Type] }
             deriving(Ord,Show)
    {-! derive: Binary !-}

-- | metavars are used in type checking
data MetaVar = MetaVar {
    metaUniq :: {-# UNPACK #-} !Int,
    metaKind :: Kind,
    metaRef :: {-# UNPACK #-} !(IORef (Maybe Type)),
    metaType :: !MetaVarType
    }
    {-! derive: Binary !-}

instance Eq MetaVar where
    a == b = metaUniq a == metaUniq b

instance Ord MetaVar where
    compare a b = compare (metaUniq a) (metaUniq b)

instance TypeNames Type where
    tBool   = TCon (Tycon tc_Bool kindStar)
    tString = TAp tList tChar
    tChar   = TCon (Tycon tc_Char kindStar)
    tUnit   = TCon (Tycon tc_Unit kindStar)
    tCharzh = TCon (Tycon tc_Char_ kindHash)

-- instance Ord (IORef a)
instance Binary (IORef a) where
  put = error "Binary.put: not impl."
  get = error "Binary.get: not impl."

tList :: Type
tList = TCon (Tycon tc_List (Kfun kindStar kindStar))

-- | The @(->)@ type constructor. Invariant: @tArrow@ shall not be fully applied. To this end, see 'tAp'.
tArrow :: Type
tArrow = TCon (Tycon tc_Arrow (kindArg `Kfun` (kindFunRet `Kfun` kindStar)))

-- | Type application, enforcing the invariant that there be no fully-applied 'tArrow's
tAp :: Type -> Type -> Type
tAp (TAp c@TCon{} a) b | c == tArrow = TArrow a b
tAp a b = TAp a b

instance Eq Type where
    (TVar a) == (TVar b) = a == b
    (TMetaVar a) == (TMetaVar b) = a == b
    (TCon a) == (TCon b) = a == b
    (TAp a' a) == (TAp b' b) = a' == b' && b == a
    (TArrow a' a) == (TArrow b' b) = a' == b' && b == a
    _ == _ = False

tassocToAp TAssoc { typeCon = con, typeClassArgs = cas, typeExtraArgs = eas } = foldl tAp (TCon con) (cas ++ eas)
tassocToAp _ = error "Representation.tassocToAp: bad."

-- Unquantified type variables

data Tyvar = Tyvar { tyvarName ::  {-# UNPACK #-} !Name, tyvarKind :: Kind }
    {-  derive: Binary -}

instance Show Tyvar where
    showsPrec _ Tyvar { tyvarName = hn, tyvarKind = k } = shows hn . ("::" ++) . shows k

tForAll [] ([] :=> t) = t
tForAll vs (ps :=> TForAll vs' (ps' :=> t)) = tForAll (vs ++ vs') ((ps ++ ps') :=> t)
tForAll x y = TForAll x y

tExists [] ([] :=> t) = t
tExists vs (ps :=> TExists vs' (ps' :=> t)) = tExists (vs ++ vs') ((ps ++ ps') :=> t)
tExists x y = TExists x y

tyvar n k = Tyvar n k

instance Eq Tyvar where
    Tyvar { tyvarName = x } == Tyvar { tyvarName = y } = x == y
    Tyvar { tyvarName = x } /= Tyvar { tyvarName = y } = x /= y

instance Ord Tyvar where
    compare (Tyvar { tyvarName = x }) (Tyvar { tyvarName = y }) = compare x y
    (Tyvar { tyvarName = x }) <= (Tyvar { tyvarName = y }) = x <= y
    (Tyvar { tyvarName = x }) >= (Tyvar { tyvarName = y }) = x >= y
    (Tyvar { tyvarName = x }) <  (Tyvar { tyvarName = y })  = x < y
    (Tyvar { tyvarName = x }) >  (Tyvar { tyvarName = y })  = x > y

-- Type constructors

data Tycon = Tycon { tyconName :: Name, tyconKind :: Kind }
    deriving(Eq, Show,Ord)
    {-! derive: Binary !-}

instance ToTuple Tycon where
    --toTuple n = Tycon (nameTuple TypeConstructor n) (foldr Kfun kindStar $ replicate n kindStar)
    toTuple n = Tycon (name_TupleConstructor typeLevel n) (foldr Kfun kindStar $ replicate n kindStar)

instance ToTuple Type where
    toTuple n = TCon $ toTuple n

instance DocLike d => PPrint d Tycon where
   pprint (Tycon i _) = pprint i

infixr      4 `fn`
fn         :: Type -> Type -> Type
a `fn` b    = TArrow a b

--------------------------------------------------------------------------------

-- Predicates
data Pred   = IsIn Class Type | IsEq Type Type
              deriving(Show, Eq,Ord)
    {-! derive: Binary !-}

-- Qualified entities
data Qual t =  [Pred] :=> t
              deriving(Show, Eq,Ord)
    {-! derive: Binary !-}

instance (DocLike d,PPrint d t) => PPrint d (Qual t) where
    pprint ([] :=> r) = pprint r
    pprint ([x] :=> r) = pprint x <+> text "=>" <+> pprint r
    pprint (xs :=> r) = tupled (map pprint xs) <+> text "=>" <+> pprint r

instance  DocLike d => PPrint d Tyvar where
  pprint tv = tshow (tyvarName tv)

instance Binary Tyvar where
    put (Tyvar aa ab) = do
        put aa
        put ab
    get = do
        aa <- get
        ab <- get
        return (Tyvar aa ab)

instance DocLike d => PPrint d Module where
   pprint s = tshow s

withNewNames ts action = subVarName $ do
    ts' <- mapM newTyvarName ts
    action ts'

newTyvarName t = case tyvarKind t of
    x@(KBase Star) -> newLookupName (map (:[]) ['a' ..]) x t
    y@(KBase Star `Kfun` KBase Star) -> newLookupName (map (('f':) . show) [0 :: Int ..]) y t
    z@(KBase KUTuple) -> newLookupName (map (('u':) . show) [0 :: Int ..]) z t
    z@(KBase KQuest) -> newLookupName (map (('q':) . show) [0 :: Int ..]) z t
    z@(KBase KQuestQuest) -> newLookupName (map (('q':) . ('q':) . show) [0 :: Int ..]) z t
    z -> newLookupName (map (('t':) . show) [0 :: Int ..]) z t

prettyPrintType :: DocLike d => Type -> d
prettyPrintType = pprint

instance DocLike d => PPrint d Type where
    pprintAssoc _ n t = prettyPrintTypePrec n t

prettyPrintTypePrec :: DocLike d => Int -> Type -> d
prettyPrintTypePrec n t  = unparse $ zup (runIdentity (runVarNameT (f t))) where
    zup = if n >= 10 then pop empty else id
    arr = bop (R,0) (space <> text "->" <> space)
    app = bop (L,100) (text " ")
    fp (IsIn cn t) = do
        t' <- f t
        return (atom (text $ show cn) `app` t')
    fp (IsEq t1 t2) = do
        t1' <- f t1
        t2' <- f t2
        return (atom (parens $ unparse t1' <+> text "=" <+> unparse t2'))
    f (TForAll [] ([] :=> t)) = f t
    f (TForAll vs (ps :=> t)) = do
        withNewNames vs $ \ts' -> do
        t' <- f t
        ps' <- mapM fp ps
        return $ case ps' of
            [] ->  fixitize (N,-3) $ pop (text "forall" <+> hsep (map text ts') <+> text ". ")  (atomize t')
            [p] -> fixitize (N,-3) $ pop (text "forall" <+> hsep (map text ts') <+> text "." <+> unparse p <+> text "=> ")  (atomize t')
            ps ->  fixitize (N,-3) $ pop (text "forall" <+> hsep (map text ts') <+> text "." <+> tupled (map unparse ps) <+> text "=> ")  (atomize t')
    f (TExists [] ([] :=> t)) = f t
    f (TExists vs (ps :=> t)) = do
        withNewNames vs $ \ts' -> do
        t' <- f t
        ps' <- mapM fp ps
        return $ case ps' of
            [] ->  fixitize (N,-3) $ pop (text "exists" <+> hsep (map text ts') <+> text ". ")  (atomize t')
            [p] -> fixitize (N,-3) $ pop (text "exists" <+> hsep (map text ts') <+> text "." <+> unparse p <+> text "=> ")  (atomize t')
            ps ->  fixitize (N,-3) $ pop (text "exists" <+> hsep (map text ts') <+> text "." <+> tupled (map unparse ps) <+> text "=> ")  (atomize t')
    f (TCon tycon) = return $ atom (pprint tycon)
    f (TVar tyvar) = do
        vo <- maybeLookupName tyvar
        case vo of
            Just c  -> return $ atom $ text c
            Nothing -> return $ atom $ tshow (tyvarName tyvar)
    f (TAp (TCon (Tycon n _)) x) | n == tc_List = do
        x <- f x
        return $ atom (char '[' <> unparse x <> char ']')
    f TAssoc { typeCon = con, typeClassArgs = cas, typeExtraArgs = eas } = do
        let x = atom (pprint con)
        xs <- mapM f (cas ++ eas)
        return $ foldl app x xs
    f ta@(TAp {}) | (TCon (Tycon c _),xs) <- fromTAp ta, Just _ <- fromTupname c = do
        xs <- mapM f xs
        return $ atom (tupled (map unparse xs))
    f (TAp t1 t2) = do
        t1 <- f t1
        t2 <- f t2
        return $ t1 `app` t2
    f (TArrow t1 t2) = do
        t1 <- f t1
        t2 <- f t2
        return $ t1 `arr` t2
    f (TMetaVar mv) = return $ atom $ pprint mv
    --f tv = return $ atom $ parens $ text ("FrontEnd.Tc.Type.pp: " ++ show tv)

instance DocLike d => PPrint d MetaVarType where
    pprint  t = case t of
        Tau -> char 't'
        Rho -> char 'r'
        Sigma -> char 's'

instance DocLike d => PPrint d Pred where
    pprint (IsIn c t) = tshow c <+> pprintParen t
    pprint (IsEq t1 t2) = parens $ prettyPrintType t1 <+> text "=" <+> prettyPrintType t2

instance DocLike d => PPrint d MetaVar where
    pprint MetaVar { metaUniq = u, metaKind = k, metaType = t }
        | KBase Star <- k =  pprint t <> tshow u
        | otherwise = parens $ pprint t <> tshow u <> text " :: " <> pprint k

instance Show MetaVarType where
    show mv = pprint mv

instance Show MetaVar where
    show mv = pprint mv

fromTAp t = f t [] where
    f (TAp a b) rs = f a (b:rs)
    f t rs = (t,rs)

fromTArrow t = f t [] where
    f (TArrow a b) rs = f b (a:rs)
    f t rs = (reverse rs,t)

instance CanType MetaVar where
    type TypeOf MetaVar = Kind
    getType mv = metaKind mv

instance CanType Tycon where
    type TypeOf Tycon = Kind
    getType (Tycon _ k) = k

instance CanType Tyvar where
    type TypeOf Tyvar = Kind
    getType = tyvarKind

instance CanType Type where
    type TypeOf Type = Kind
    getType (TCon tc) = getType tc
    getType (TVar u)  = getType u
    getType typ@(TAp t _) = case (getType t) of
                       (Kfun _ k) -> k
                       x -> error $ "Representation.getType: kind error in: " ++ (show typ)
    getType (TArrow _l _r) = kindStar
    getType (TForAll _ (_ :=> t)) = getType t
    getType (TExists _ (_ :=> t)) = getType t
    getType (TMetaVar mv) = getType mv
    getType ta@TAssoc {} = getType (tassocToAp ta)

tTTuple [] = tUnit
tTTuple [_]  = error "tTTuple"
tTTuple ts = foldl TAp (toTuple (length ts)) ts

tTTuple' ts = foldl TAp (TCon $ Tycon (name_UnboxedTupleConstructor typeLevel n) (foldr Kfun kindUTuple $ replicate n kindStar)) ts where
    n = length ts
{-* Generated by DrIFT : Look, but Don't Touch. *-}
instance Data.Binary.Binary MetaVarType where
    put Tau = do
            Data.Binary.putWord8 0
    put Rho = do
            Data.Binary.putWord8 1
    put Sigma = do
            Data.Binary.putWord8 2
    get = do
            h <- Data.Binary.getWord8
            case h of
              0 -> do
                    return Tau
              1 -> do
                    return Rho
              2 -> do
                    return Sigma
              _ -> fail "invalid binary data found"

instance Data.Binary.Binary Type where
    put (TVar aa) = do
            Data.Binary.putWord8 0
            Data.Binary.put aa
    put (TCon ab) = do
            Data.Binary.putWord8 1
            Data.Binary.put ab
    put (TAp ac ad) = do
            Data.Binary.putWord8 2
            Data.Binary.put ac
            Data.Binary.put ad
    put (TArrow ae af) = do
            Data.Binary.putWord8 3
            Data.Binary.put ae
            Data.Binary.put af
    put (TForAll ag ah) = do
            Data.Binary.putWord8 4
            Data.Binary.put ag
            Data.Binary.put ah
    put (TExists ai aj) = do
            Data.Binary.putWord8 5
            Data.Binary.put ai
            Data.Binary.put aj
    put (TMetaVar ak) = do
            Data.Binary.putWord8 6
            Data.Binary.put ak
    put (TAssoc al am an) = do
            Data.Binary.putWord8 7
            Data.Binary.put al
            Data.Binary.put am
            Data.Binary.put an
    get = do
            h <- Data.Binary.getWord8
            case h of
              0 -> do
                    aa <- Data.Binary.get
                    return (TVar aa)
              1 -> do
                    ab <- Data.Binary.get
                    return (TCon ab)
              2 -> do
                    ac <- Data.Binary.get
                    ad <- Data.Binary.get
                    return (TAp ac ad)
              3 -> do
                    ae <- Data.Binary.get
                    af <- Data.Binary.get
                    return (TArrow ae af)
              4 -> do
                    ag <- Data.Binary.get
                    ah <- Data.Binary.get
                    return (TForAll ag ah)
              5 -> do
                    ai <- Data.Binary.get
                    aj <- Data.Binary.get
                    return (TExists ai aj)
              6 -> do
                    ak <- Data.Binary.get
                    return (TMetaVar ak)
              7 -> do
                    al <- Data.Binary.get
                    am <- Data.Binary.get
                    an <- Data.Binary.get
                    return (TAssoc al am an)
              _ -> fail "invalid binary data found"

instance Data.Binary.Binary MetaVar where
    put (MetaVar aa ab ac ad) = do
            Data.Binary.put aa
            Data.Binary.put ab
            Data.Binary.put ac
            Data.Binary.put ad
    get = do
    aa <- get
    ab <- get
    ac <- get
    ad <- get
    return (MetaVar aa ab ac ad)

instance Data.Binary.Binary Tycon where
    put (Tycon aa ab) = do
            Data.Binary.put aa
            Data.Binary.put ab
    get = do
    aa <- get
    ab <- get
    return (Tycon aa ab)

instance Data.Binary.Binary Pred where
    put (IsIn aa ab) = do
            Data.Binary.putWord8 0
            Data.Binary.put aa
            Data.Binary.put ab
    put (IsEq ac ad) = do
            Data.Binary.putWord8 1
            Data.Binary.put ac
            Data.Binary.put ad
    get = do
            h <- Data.Binary.getWord8
            case h of
              0 -> do
                    aa <- Data.Binary.get
                    ab <- Data.Binary.get
                    return (IsIn aa ab)
              1 -> do
                    ac <- Data.Binary.get
                    ad <- Data.Binary.get
                    return (IsEq ac ad)
              _ -> fail "invalid binary data found"

instance (Data.Binary.Binary t) => Data.Binary.Binary (Qual t) where
    put ((:=>) aa ab) = do
            Data.Binary.put aa
            Data.Binary.put ab
    get = do
    aa <- get
    ab <- get
    return ((:=>) aa ab)

--  Imported from other files :-
