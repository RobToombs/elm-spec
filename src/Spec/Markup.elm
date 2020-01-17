module Spec.Markup exposing
  ( MarkupObservation
  , HtmlElement
  , observeTitle
  , observe
  , observeElement
  , observeElements
  , query
  , target
  , property
  , text
  , attribute
  )

{-| Target, observe and make claims about aspects of an HTML document.

# Target an HTML Element
@docs target

# Observe an HTML Document
@docs MarkupObservation, observeElements, observeElement, observe, query, observeTitle

# Make Claims about an HTML Element
@docs HtmlElement, text, attribute, property

-}

import Spec.Observer as Observer exposing (Observer)
import Spec.Observer.Internal as Observer
import Spec.Claim as Claim exposing (Claim)
import Spec.Report as Report exposing (Report)
import Spec.Markup.Selector as Selector exposing (Selector, Element)
import Spec.Step as Step
import Spec.Step.Command as Command
import Spec.Message as Message exposing (Message)
import Json.Encode as Encode
import Json.Decode as Json
import Dict exposing (Dict)


{-| Observe the title of an HTML document.

Note: It only makes sense to observe the title if your program is constructed with
`Browser.document` or `Browser.application`.
-}
observeTitle : Observer model String
observeTitle =
  Observer.inquire selectTitleMessage <| \message ->
    Message.decode Json.string message
      |> Result.withDefault "FAILED"


selectTitleMessage : Message
selectTitleMessage =
  Message.for "_html" "application"
    |> Message.withBody (Encode.string "select-title")


{-| Represents an observation of HTML.
-}
type MarkupObservation a =
  MarkupObservation
    { query: Query
    , inquiryHandler: Selector Element -> Message -> Result Report a
    }


type Query
  = Single
  | All


{-| Observe an HTML element that may not be present in the document.

Use this observer if you want to make a claim about the presence or absence of an HTML element.

    Spec.Markup.observe
      |> Spec.Markup.query << by [ id "some-element" ]
      |> Spec.expect Spec.Claim.isNothing

-}
observe : MarkupObservation (Maybe HtmlElement)
observe =
  MarkupObservation
    { query = Single
    , inquiryHandler = \selection message ->
        Message.decode maybeHtmlDecoder message
          |> Result.mapError (\err ->
            Report.fact "Unable to decode element JSON!" err
          )
    }

{-| Observe an HTML element that matches the selector provided to `Spec.Markup.query`.

    Spec.Markup.observeElement
      |> Spec.Markup.query << by [ attribute ("data-attr", "some-value") ]
      |> Spec.expect (Spec.Markup.text <| 
        Spec.Claim.isEqual Debug.toString "something fun"
      )

If the element cannot be found in the document, the claim will be rejected.
-}
observeElement : MarkupObservation HtmlElement
observeElement =
  MarkupObservation
    { query = Single
    , inquiryHandler = \selection message ->
        Message.decode maybeHtmlDecoder message
          |> Result.mapError (\err ->
            Report.fact "Unable to decode element JSON!" err
          )
          |> Result.andThen (\maybeElement ->
            case maybeElement of
              Just element ->
                Ok element
              Nothing ->
                Err <| Report.fact "No element matches selector" (Selector.toString selection)
          )
    }


{-| Observe all HTML elements that match the selector provided to `Spec.Markup.query`.

    Spec.Markup.observeElements
      |> Spec.Markup.query << by [ attribute ("data-attr", "some-value") ]
      |> Spec.expect (Spec.Claim.isListWithLength 3)

If no elements match the query, then the subject of the claim will be an empty list.
-}
observeElements : MarkupObservation (List HtmlElement)
observeElements =
  MarkupObservation
    { query = All
    , inquiryHandler = \selection message ->
        Message.decode (Json.list htmlDecoder) message
          |> Result.mapError (\err ->
            Report.fact "Unable to decode element JSON!" err
          )
    }


{-| Search for HTML elements.

Use this function in conjunction with `observe`, `observeElement`, or `observeElements` to
observe the HTML document.
-}
query : (Selector Element, MarkupObservation a) -> Observer model a
query (selection, MarkupObservation observation) =
  let
    message =
      queryMessage observation.query selection
  in
    Observer.inquire message (observation.inquiryHandler selection)
      |> Observer.observeResult
      |> Observer.mapRejection (\report ->
        Report.batch
        [ Report.fact "Claim rejected for selector" <| Selector.toString selection
        , report
        ]
      )


{-| A step that identifies an element to which later steps will be applied.

    Spec.when "the button is clicked twice"
      [ Spec.Markup.target << by [ tag "button" ]
      , Spec.Markup.Event.click
      , Spec.Markup.Event.click
      ]

-}
target : (Selector a, Step.Context model) -> Step.Command msg
target (selection, context) =
  Message.for "_html" "target"
    |> Message.withBody (Encode.string <| Selector.toString selection)
    |> Command.sendMessage


queryMessage : Query -> Selector Element -> Message
queryMessage queryType selection =
  Message.for "_html" (queryName queryType)
    |> Message.withBody (
      Encode.object
        [ ( "selector", Encode.string <| Selector.toString selection )
        ]
    )


queryName : Query -> String
queryName queryType =
  case queryType of
    Single ->
      "query"
    All ->
      "queryAll"


{-| Represents an HTML element.
-}
type HtmlElement =
  HtmlElement Json.Value


maybeHtmlDecoder : Json.Decoder (Maybe HtmlElement)
maybeHtmlDecoder =
  Json.oneOf
    [ Json.null Nothing
    , Json.map Just <| htmlDecoder
    ]


htmlDecoder : Json.Decoder HtmlElement
htmlDecoder =
  Json.map HtmlElement <| Json.value


{-| Claim that the HTML element's text satisfies the given claim.

    Spec.Markup.observeElement
      |> Spec.Markup.query << by [ tag "div" ]
      |> Spec.expect (
        Spec.Markup.text <|
          Spec.Claim.isStringContaining 1 "red"
      )

Note that an observed HTML element's text includes the text belonging to
all its descendants.
-}
text : Claim String -> Claim HtmlElement
text claim =
  \(HtmlElement element) ->
    case Json.decodeValue (Json.field "textContent" Json.string) element of
      Ok actualText ->
        claim actualText
          |> Claim.mapRejection (\report -> Report.batch
            [ Report.note "Claim rejected for element text"
            , report
            ]
          )
      Err err ->
        Claim.Reject <| Report.fact "Unable to decode JSON for text" <| Json.errorToString err


{-| Claim that the specified attribute value satisfies the given claim.

    Spec.Markup.observeElement
      |> Spec.Markup.query << by [ tag "div" ]
      |> Spec.expect (
        Spec.Markup.attribute "class" <|
          Spec.Claim.isSomethingWhere <|
          Spec.Claim.isStringContaining 1 "red"
      )

-}
attribute : String -> Claim (Maybe String) -> Claim HtmlElement
attribute name claim =
  \(HtmlElement element) ->
    case Json.decodeValue attributesDecoder element of
      Ok attributes ->
        Dict.get name attributes
          |> claim
          |> Claim.mapRejection (\report -> Report.batch
              [ Report.fact "Claim rejected for attribute" name
              , report
              ]
          )
      Err err ->
        Claim.Reject <| Report.fact "Unable to decode JSON for attributes" <| Json.errorToString err


attributesDecoder : Json.Decoder (Dict String String)
attributesDecoder =
  Json.map Dict.fromList <|
    Json.field "attributes" <|
    Json.map (List.map Tuple.second) <|
    Json.keyValuePairs <|
    Json.map2 Tuple.pair
      (Json.field "name" Json.string)
      (Json.field "value" Json.string)


{-| Apply the given decoder to the HTML element and make a claim about the resulting value.

Use this function to observe a property of an HTML element. For example, you could observe whether
a button is disabled like so:

    Spec.Markup.observeElement
      |> Spec.Markup.query << by [ tag "button" ]
      |> Spec.expect (
        Spec.Markup.property
          (Json.Decode.field "disabled" Json.Decode.bool)
          Spec.Claim.isTrue
      )

On the difference between attributes and properties,
see [this](https://github.com/elm-lang/html/blob/master/properties-vs-attributes.md).

-}
property : Json.Decoder a -> Claim a -> Claim HtmlElement
property decoder claim =
  \(HtmlElement element) ->
    case Json.decodeValue decoder element of
      Ok propertyValue ->
        claim propertyValue
      Err err ->
        Claim.Reject <| Report.fact "Unable to decode JSON for property" <| Json.errorToString err
