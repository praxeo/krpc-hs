{-# LANGUAGE RecordWildCards #-}

module Main
( main
) where


import KRPCHS
import KRPCHS.SpaceCenter

import Control.Monad
import Control.Monad.Catch
import Control.Monad.Trans

import Data.List


data TelemetryData = TelemetryData
    { time      :: Double
    , altitude  :: Double
    , latitude  :: Double
    , longitude :: Double
    , mass      :: Float
    , thrust    :: Float
    }


main :: IO ()
main =
    withRPCClient    "Flight recorder" "127.0.0.1" "50000" $ \client       ->
    withStreamClient client            "127.0.0.1" "50001" $ \streamClient ->
        runRPCProg client (telemetryProg streamClient)


telemetryProg :: StreamClient -> RPCContext ()
telemetryProg streamClient = do
    vessel <- getActiveVessel
    ref    <- getVesselSurfaceReferenceFrame vessel
    flight <- vesselFlight vessel ref

    -- install streams
    timeStream      <- getUTStream
    altitudeStream  <- getFlightMeanAltitudeStream flight
    latitudeStream  <- getFlightLatitudeStream     flight
    longitudeStream <- getFlightLongitudeStream    flight
    massStream      <- getVesselMassStream         vessel
    thrustStream    <- getVesselThrustStream       vessel

    -- get results and print csv
    liftIO $ putStrLn "time;altitude;latitude;longitude;mass;thrust"
    forever $ do
        msg <- getStreamMessage streamClient

        ok <- try (do
            time      <- getStreamResult timeStream      msg
            altitude  <- getStreamResult altitudeStream  msg
            latitude  <- getStreamResult latitudeStream  msg
            longitude <- getStreamResult longitudeStream msg
            mass      <- getStreamResult massStream      msg
            thrust    <- getStreamResult thrustStream    msg
            return TelemetryData{..})

        case ok of
            Right telemetry    -> liftIO $ printTelemetryCSV telemetry
            Left  NoSuchStream -> return () -- this can happen during the first few loops
            Left  err          -> throwM err


printTelemetryCSV :: TelemetryData -> IO ()
printTelemetryCSV TelemetryData{..} =
    putStrLn $ intercalate ";" [show time, show altitude, show latitude, show longitude, show mass, show thrust]
