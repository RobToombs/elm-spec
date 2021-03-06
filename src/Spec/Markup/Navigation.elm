module Spec.Markup.Navigation exposing
  ( observeLocation
  , expectReload
  )

{-| Functions for observing navigation changes.

@docs observeLocation, expectReload

-}

import Spec exposing (Expectation)
import Spec.Observer as Observer exposing (Observer)
import Spec.Observer.Internal as Observer
import Spec.Claim as Claim
import Spec.Report as Report
import Spec.Message as Message exposing (Message)
import Spec.Markup.Message as Message
import Json.Encode as Encode
import Json.Decode as Json


{-| Observe the current location of the document.

    Spec.it "has the correct location" (
      observeLocation
        |> Spec.expect (
           Spec.Claim.isEqual Debug.toString
             "http://fake-server.com/something-fun"
        )
    )

This is useful to observe that `Browswer.Navigation.load`,
`Browser.Navigation.pushUrl`, or `Browser.Navigation.replaceUrl` was
executed with the value you expect.

Note that you can use `Spec.Setup.withLocation` to set the base location
of the document at the start of the scenario.

-}
observeLocation : Observer model String
observeLocation =
  Observer.inquire Message.fetchWindow <| \message ->
    Message.decode locationDecoder message
      |> Result.withDefault "FAILED"


locationDecoder : Json.Decoder String
locationDecoder =
  Json.at [ "location", "href" ] Json.string


{-| Expect that a `Browser.Navigation.reload` or `Browser.Navigation.reloadAndSkipCache`
command was executed.
-}
expectReload : Expectation model
expectReload =
  Observer.observeEffects (List.filter (Message.is "_navigation" "reload"))
    |> Spec.expect (\messages ->
      if List.length messages > 0 then
        Claim.Accept
      else
        Claim.Reject <| Report.note "Expected Browser.Navigation.reload or Browser.Navigation.reloadAndSkipCache but neither command was executed"
    )