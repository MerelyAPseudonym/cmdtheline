import System.Console.CmdTheLine
import Control.Applicative

import System.Directory ( copyFile
                        , doesFileExist
                        , doesDirectoryExist
                        )
import System.FilePath  ( takeFileName
                        , pathSeparator
                        , hasTrailingPathSeparator
                        )

import System.IO
import System.Exit ( exitFailure )

sep = [pathSeparator]

infixr 1 ?
-- Like C's ternary operator. 'predicate ? then-clause $ else-clause'.
-- Nice for nested, if-elseif style boolean bifurcation.
(?) True  = const
(?) False = flip const

cp :: Bool -> [String] -> String -> IO ()
cp dry sources dest =
  chooseTactic =<< doesDirectoryExist dest
  where
  chooseTactic isDir = 
    singleFile ? singleCopy isDir $
    not isDir  ? notDirErr $
    mapM_ copySourcesToDir sources

  singleFile = length sources == 1

  -- Errors
  notDirErr = do
    hPutStrLn stderr $ "cp: target '" ++ dest ++ "' is not a directory"
    exitFailure

  notFileErr str = do
    hPutStrLn stderr $ "cp: '" ++ str ++ "': no such file"
    exitFailure

  -- Tactics
  singleCopy isDir = do
    choose =<< doesFileExist filePath
    where
    choose isFile =
      isFile && isDir ? copyToDir  filePath $
      isFile          ? copyToFile filePath $
      notFileErr filePath

    filePath = head sources

  copySourcesToDir filePath = do
    isFile <- doesFileExist filePath
    isFile ? copyToDir  filePath
           $ notFileErr filePath

  -- File copying
  copyToDir filePath = if dry
    then putStrLn $ concat [ "cp: copying ", filePath, " to ", dest' ]
    else copyFile filePath dest'
    where
    dest'           = withTrailingSep ++ takeFileName filePath
    withTrailingSep = hasTrailingPathSeparator dest ? dest $ dest ++ sep

  copyToFile filePath = if dry
    then putStrLn $ concat [ "cp: copying ", filePath, " to ", dest ]
    else copyFile filePath dest


-- An example of using the 'rev' and 'Left' variants of 'pos'.
cpTerm = cp <$> dry <*> sources <*> dest
  where
  dry = value $ flag (optInfo [ "dry", "d" ])
      { optName = "DRY"
      , optDoc  = "Perform a dry run.  Print what would be copied, but do not "
               ++ "copy it."
      }

  sources = nonEmpty $ revPosLeft 0 [] posInfo
          { posName = "SOURCES"
          , posDoc  = "Source file(s) to copy."
          }

  dest    = required $ revPos 0 Nothing posInfo
          { posName = "DEST"
          , posDoc  = "Destination of the copy. Must be a directory if there "
                   ++ "is more than one $(i,SOURCE)."
          }

termInfo = defTI
  { termName = "cp"
  , version  = "v1.0"
  , termDoc  = "Copy files from SOURCES to DEST."
  , man      = [ S "BUGS"
               , P "Email bug reports to <portManTwo@example.com>"
               ]
  }

main = run ( cpTerm, termInfo )
