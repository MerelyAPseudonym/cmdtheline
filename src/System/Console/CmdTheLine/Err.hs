{- Copyright © 2012, Vincent Elisha Lee Frey.  All rights reserved.
 - This is open source software distributed under a MIT license.
 - See the file 'LICENSE' for further information.
 -}
module System.Console.CmdTheLine.Err where

import System.Console.CmdTheLine.Common
import qualified System.Console.CmdTheLine.Help as H

import Text.PrettyPrint
import Data.List ( intersperse )

import Control.Monad ( join )
import Control.Monad.Trans.Error

import System.IO

-- | Fail with an arbitrary message on failure.
msgFail :: Doc -> Err a
msgFail = throwError . MsgFail

-- | Fail with a message along with the usage on failure.
usageFail :: Doc -> Err a
usageFail = throwError . UsageFail

-- | A format to print the help in and an optional name of the term to print
-- help for.  If 'Nothing' is supplied, help will be printed for the currently
-- evaluating term.
helpFail :: HelpFormat -> Maybe String -> Err a
helpFail fmt = throwError . HelpFail fmt

-- | 'ret' @term@ folds @term@'s 'Err' context into the library to be handled
-- internally and as seamlessly as other error messages that are built in.
ret :: Term (Err a) -> Term a
ret (Term ais yield) = Term ais yield'
  where
  yield' ei cl = join $ yield ei cl


hsepMap :: (a -> Doc) -> [a] -> Doc
hsepMap f = hsep . map f

errArgv     = text "argv array must have at least one element"
errNotOpt   = "Option argument without name"
errNotPos   = "Positional argument with a name"
errHelp doc = text "term error, help requested for unknown command" <+> doc


alts []    = error "alts called on empty list"
alts [x]   = error "alts called on singleton list"
alts [x,y] = hsepMap text [ "either", x, "or", y ]
alts xs    = text "one of:" <+> fsep (punctuate (char ',') (map text xs))

invalid kind s exp = hsep
  [ text "invalid", text kind, quotes s<>char ',', exp ]

invalidVal = invalid "value"

no kind s = sep [ text "no such", text kind, quotes $ text s ]

notDir  s = quotes (s) <+> text "is not a directory"

isDir   s = quotes (s) <+> text "is a directory"

element kind str exp = fsep
  [ text "invalid element in", text kind, parens . quotes $ text str, exp ]

sepMiss sep str = invalidVal (text str) $
  hsep [ text "missing a", quotes $ char sep, text "separator" ]

unknown kind v = sep [ text "unknown", text kind, quotes $ text v ]

ambiguous kind s ambs = hsep
  [ text kind, quotes $ text s, text "ambiguous, could be", alts ambs ]

posExcess excess = text "too many arguments, don't know what to do with"
               <+> hsepMap prep excess
  where
  prep = (<> text ",") . quotes

flagValue f v = hsep
  [ text "option", quotes $ text f
  , text "is a flag, it cannot take the argument", quotes $ text v
  ]

optValueMissing f = hsep
  [ text "option", quotes $ text f, text "needs an argument" ]
optParseValue f e = sep [ text "option" <+> (quotes (text f)<>char ':'), e ]
optRepeated f f'
  | f == f' = hsep
    [ text "option", quotes $ text f, text "cannot be repeated" ]
  | otherwise         = hsep
    [ text "options", quotes $ text f, text "and", quotes $ text f'
    , text "cannot be present at the same time"
    ]

posParseValue :: ArgInfo -> Doc -> Doc
posParseValue ai e
  | argName ai == "" = e
  | otherwise        = case posKind ai of
    (PosN _ _) -> hsep [ name, arg, e ]
    _          -> hsep [ name<>text "...", arg, e ]
    where
    name = text $ argName ai
    arg  = text "arguments:"

argMissing :: ArgInfo -> Doc
argMissing ai
  | isOpt ai  = hsepMap text [ "required option", longName $ optNames ai ]
  | otherwise =
    if name == ""
       then text "a required argument is missing"
       else hsepMap text [ "required argument", name, "is missing" ]
    where
    name = argName ai

    longName (x : xs)
      | length x > 2 || xs == [] = x
      | otherwise                = longName xs

print :: Handle -> EvalInfo -> Doc -> IO ()
print h ei e = hPrint h $ (text . termName . fst $ main ei) <> char ':' <+> e

prepTryHelp :: EvalInfo -> String
prepTryHelp ei =
  if execName == mainName
     then concat [ "Try '", execName, " --help' for more information." ]
     else concat [ "Try '", execName, " --help' or '"
                 , mainName, " --help' for more information" ]
  where
  execName = H.invocation '-' ei
  mainName = termName . fst $ main ei

printUsage :: Handle -> EvalInfo -> Doc -> IO ()
printUsage h ei e = hPrint h $ sep
  [ text ((termName . fst $ main ei) ++ ":") <+> e
  , sep [ text "Usage:", text $ H.prepSynopsis ei ]
  , text $ prepTryHelp ei
  ]
