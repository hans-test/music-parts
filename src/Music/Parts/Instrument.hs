
{-| Representation of musical instruments.

The 'Instrument' type represent any instrument in the MusicXML Standard Sounds 3.0 set,
with some extensions. See <http://www.musicxml.com/for-developers/standard-sounds>.
-}
module Music.Parts.Instrument (
        Instrument,

        -- * Name
        -- instrumentName,
        fullName,
        shortName,
        fromMidiProgram,
        toMidiProgram,
        fromMusicXmlSoundId,
        toMusicXmlSoundId,

        -- * Clefs and transposition
        transposition,
        transpositionString,
        standardClef,
        allowedClefs,

        -- * Playing range
        playableRange,
        comfortableRange,
        -- playableDynamics,
  ) where

import           Control.Applicative
import           Control.Lens                    (toListOf)
import           Data.Aeson                      (ToJSON (..), FromJSON(..))
import qualified Data.Aeson
import           Data.Default
import qualified Data.List
import           Data.Map                        (Map)
import qualified Data.Maybe
import           Data.Semigroup
import           Data.Semigroup.Option.Instances
import           Data.Set                        (Set)
import qualified Data.Set
import           Data.Traversable                (traverse)
import           Data.Typeable
import           Text.Numeral.Roman              (toRoman)

import           Music.Dynamics                  (Dynamics)
import           Music.Parts.Internal.Data       (InstrumentDef)
import qualified Music.Parts.Internal.Data       as Data
import           Music.Pitch

{-
Instrument is represented either by instrument ID or (more concisely) as GM program number.
The first GM program match in the data table is used.

Instruments not in the MusicXML 3 standard has has ".x." as part of their ID.
-}

-- | An 'Instrument' represents the set of all instruments of a given type.
data Instrument
    = StdInstrument Int
    | OtherInstrument String

instance Show Instrument where
    show x = Data.Maybe.fromMaybe "(unknown)" $ fullName x

instance Eq Instrument where
  x == y = soundId x == soundId y

instance Ord Instrument where
  compare x y = compare (scoreOrder x) (scoreOrder y)

-- | This instance is quite arbitrary but very handy.
instance Default Instrument where
    def = StdInstrument 0

instance ToJSON Instrument where
  toJSON (StdInstrument x) = Data.Aeson.object [("midi-instrument", toJSON x)]
  toJSON (OtherInstrument x) = Data.Aeson.object [("instrument-id", toJSON x)]

instance FromJSON Instrument where
  parseJSON (Data.Aeson.Object v) = do
    mi <- v Data.Aeson..:? "midi-instrument"
    ii <- v Data.Aeson..:? "instrument-id"
    case (mi,ii) of
      (Just mi,_)       -> return $ fromMidiProgram mi
      (Nothing,Just ii) -> return $ fromMusicXmlSoundId ii
      _ -> empty
  parseJSON _ = empty


-- | Create an instrument from a MIDI program number.
-- Given number should be in the range 0 - 127.
fromMidiProgram :: Int -> Instrument
fromMidiProgram = StdInstrument

-- | Convert an instrument to a MIDI program number.
-- If the given instrument is not representable as a MIDI program, return @Nothing@.
toMidiProgram :: Instrument -> Maybe Int
toMidiProgram = fmap pred . Data.Maybe.listToMaybe . Data._generalMidiProgram . fetchInstrumentDef

-- | Create an instrument from a MusicXML Standard Sound ID.
fromMusicXmlSoundId :: String -> Instrument
fromMusicXmlSoundId = OtherInstrument

-- | Convert an instrument to a MusicXML Standard Sound ID.
-- If the given instrument is not in the MusicXMl standard, return @Nothing@.
toMusicXmlSoundId :: Instrument -> Maybe String
toMusicXmlSoundId = Just . soundId
-- TODO filter everything with .x. in them

soundId :: Instrument -> String
soundId = Data._soundId . fetchInstrumentDef

-- | Clefs allowed for this instrument.
allowedClefs      :: Instrument -> Set Clef
allowedClefs = Data.Set.fromList . Data._allowedClefs . fetchInstrumentDef

-- | Standard clef used for this instrument.
standardClef      :: Instrument -> Maybe Clef
standardClef = Data.Maybe.listToMaybe . Data._standardClef . fetchInstrumentDef
-- TODO what about multi-staves?

data BracketType = Bracket | Brace | SubBracket
data StaffLayout = Staff Clef | Staves BracketType [StaffLayout]

pianoStaff :: StaffLayout
pianoStaff = Staves Brace [Staff trebleClef, Staff bassClef]

-- | Playable range for this instrument.
playableRange     :: Instrument -> Ambitus Pitch
playableRange = Data.Maybe.fromMaybe (error "Missing comfortableRange for instrument") . Data._playableRange . fetchInstrumentDef

-- | Comfortable range for this instrument.
comfortableRange  :: Instrument -> Ambitus Pitch
comfortableRange = Data.Maybe.fromMaybe (error "Missing comfortableRange for instrument") . Data._comfortableRange . fetchInstrumentDef

-- playableDynamics :: Instrument -> Pitch -> Dynamics
-- playableDynamics = error "No playableDynamics"

-- instrumentName              :: Instrument -> String
-- instrumentName = error "No name"

-- | Full instrument name.
fullName          :: Instrument -> Maybe String
-- for now use _sibeliusName if present
fullName x = Data._sibeliusName (fetchInstrumentDef x) `first` Data._longName (fetchInstrumentDef x)
  where
    first (Just x) _ = Just x
    first _ (Just x) = Just x
    first Nothing Nothing = Nothing

-- | Instrument name abbrevation.
shortName         :: Instrument -> Maybe String
shortName = Data._shortName . fetchInstrumentDef

-- sounding .-. written, i.e. -P5 for horn
-- | Transposition interval.
transposition :: Instrument -> Interval
transposition = Data._transposition . fetchInstrumentDef
  where

-- | A string representing transposition such as "Bb" or "F".
transpositionString :: Instrument -> String
transpositionString x = pitchToPCString (c .+^ transposition x)
-- pitch class sounding when c is notated (i.e. F for Horn in F)




-- TODO move
pitchToPCString :: Pitch -> String
pitchToPCString x = show (name x) ++ showA (accidental x)
  where
    showA 1    = "#"
    showA 0    = ""
    showA (-1) = "b"


scoreOrder :: Instrument -> Double
scoreOrder = Data._scoreOrder . fetchInstrumentDef

-- internal
fetchInstrumentDef :: Instrument -> InstrumentDef
fetchInstrumentDef (StdInstrument x)   = Data.Maybe.fromMaybe (error "Bad instr") $ Data.getInstrumentDefByGeneralMidiProgram (x + 1)
fetchInstrumentDef (OtherInstrument x) = Data.Maybe.fromMaybe (error "Bad instr") $ Data.getInstrumentDefById x
