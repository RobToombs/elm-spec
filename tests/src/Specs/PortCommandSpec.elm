port module Specs.PortCommandSpec exposing (..)

import Spec exposing (Spec)
import Spec.Subject as Subject
import Spec.Port as Port
import Observer
import Runner
import Json.Decode as Json


witnessPortCommandFromInitSpec : Spec Model Msg
witnessPortCommandFromInitSpec =
  Spec.given (
    Subject.worker (\_ -> ({count = 0}, sendTestMessageOut "From init!")) testUpdate
      |> Port.observe "sendTestMessageOut"
  )
  |> Spec.it "sends the expected message" (
    Port.expect "sendTestMessageOut" Json.string <|
      Observer.isEqual [ "From init!" ]
  )


witnessMultiplePortCommandsFromInitSpec : Spec Model Msg
witnessMultiplePortCommandsFromInitSpec =
  Spec.given (
    Subject.worker (\_ -> 
        ( {count = 0}
        , Cmd.batch [ sendTestMessageOut "One", sendTestMessageOut "Two", sendTestMessageOut "Three" ]
        )
      )
      testUpdate
      |> Port.observe "sendTestMessageOut"
  )
  |> Spec.it "records all the messages sent" (
    Port.expect "sendTestMessageOut" Json.string <|
      Observer.isEqual [ "One", "Two", "Three" ]
  )


testUpdate : Msg -> Model -> ( Model, Cmd Msg )
testUpdate _ model =
  ( model, Cmd.none )


selectSpec : String -> Spec Model Msg
selectSpec name =
  case name of
    "one" ->
      witnessPortCommandFromInitSpec
    "many" ->
      witnessMultiplePortCommandsFromInitSpec
    _ ->
      witnessPortCommandFromInitSpec


type Msg
  = Msg


type alias Model =
  { count: Int
  }


port sendTestMessageOut : String -> Cmd msg


main =
  Runner.program selectSpec