port module WithNoSendInPort.Runner exposing (..)

import Spec exposing (Spec)
import Spec.Runner
import Spec.Message exposing (Message)


port elmSpecOut : Message -> Cmd msg
port somethingOtherThanSendIn : (Message -> msg) -> Sub msg


config : Spec.Runner.Config msg
config =
  { send = elmSpecOut
  , outlet = elmSpecOut
  , listen = somethingOtherThanSendIn
  }


program specs =
  Spec.Runner.browserProgram config specs


workerProgram specs =
  Spec.Runner.program config specs