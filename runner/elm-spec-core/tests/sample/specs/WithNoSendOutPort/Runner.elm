port module WithNoSendOutPort.Runner exposing (..)

import Spec exposing (Spec)
import Spec.Runner
import Spec.Message exposing (Message)


port somerthingOtherThanSendOut : Message -> Cmd msg
port elmSpecIn : (Message -> msg) -> Sub msg


config : Spec.Runner.Config msg
config =
  { send = somerthingOtherThanSendOut
  , outlet = somerthingOtherThanSendOut
  , listen = elmSpecIn
  }


program specs =
  Spec.Runner.browserProgram config specs


workerProgram specs =
  Spec.Runner.program config specs