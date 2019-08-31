module Spec.Html exposing
  ( Selector(..)
  , Selection(..)
  , select
  , target
  , expectElement
  , expectElements
  , hasText
  )

import Spec exposing (Expectation)
import Spec.Actual as Actual
import Spec.Observer as Observer exposing (Observer)
import Spec.Observer.Report as Report
import Spec.Subject exposing (Subject)
import Spec.Message as Message exposing (Message)
import Json.Encode as Encode
import Json.Decode as Json


type Selector
  = Id String
  | Tag String
  | AttributeName String


type Selection
  = By (List Selector)


target : Selection -> Message
target selection =
  { home = "_html"
  , name = "target"
  , body = Encode.string <| toString selection
  }


select : Selection -> Selection
select =
  identity


toString : Selection -> String
toString selection =
  case selection of
    By selectors ->
      firstTagSelector selectors
        |> anyOtherSelectors selectors


firstTagSelector : List Selector -> String
firstTagSelector selectors =
  selectors
    |> List.filterMap (\selector -> 
      case selector of
        Tag name ->
          Just name
        _ ->
          Nothing
    )
    |> List.head
    |> Maybe.withDefault ""


anyOtherSelectors : List Selector -> String -> String
anyOtherSelectors selectors selString =
  selectors
    |> List.foldl (\selector output ->
      case selector of
        Id name ->
          output ++ "#" ++ name
        AttributeName name ->
          output ++ "[" ++ name ++ "]"
        _ ->
          output  
    ) selString


selectHtml : Selection -> Message
selectHtml selection =
  { home = "_html"
  , name = "select"
  , body = Encode.object [ ("selector", Encode.string <| toString selection) ]
  }


selectAllHtml : Selection -> Message
selectAllHtml selection =
  { home = "_html"
  , name = "selectAll"
  , body = Encode.object [ ("selector", Encode.string <| toString selection) ]
  }


expectElement : Observer HtmlElement -> (() -> Selection) -> Expectation model msg
expectElement observer selectionGenerator =
  let
    selection = selectionGenerator ()
  in
    Actual.inquire (selectHtml selection)
      |> Actual.map (Message.decode htmlDecoder)
      |> Spec.expect (\maybeElement ->
        case maybeElement of
          Just element ->
            observer element
          Nothing ->
            Observer.Reject <| Report.fact "No element matches selector" (toString selection)
      )


expectElements : Observer (List HtmlElement) -> (() -> Selection) -> Expectation model msg
expectElements observer selectionGenerator =
  Actual.inquire (selectAllHtml <| selectionGenerator ())
    |> Actual.map (Message.decode <| Json.list htmlDecoder)
    |> Actual.map (Maybe.withDefault [])
    |> Spec.expect observer


type HtmlNode
  = Element HtmlElement
  | Text String


type alias HtmlElement =
  { tag: String
  , children: List HtmlNode
  }


emptyElement : HtmlElement
emptyElement =
  { tag = ""
  , children = []
  }


htmlDecoder : Json.Decoder HtmlElement
htmlDecoder =
  Json.map2 HtmlElement
    ( Json.field "tag" Json.string )
    ( Json.field "children" <| Json.list <| 
      Json.oneOf
        [ Json.map Text <| Json.field "text" Json.string
        , Json.map Element <| Json.lazy (\_ -> htmlDecoder)
        ]
    )


hasText : String -> Observer HtmlElement
hasText expectedText element =
  if List.member expectedText <| flattenTexts element.children then
    Observer.Accept
  else
    Observer.Reject <| Report.batch
      [ Report.fact "Expected text" expectedText
      , Report.fact "but the actual text was" <| String.join ", " <| flattenTexts element.children
      ]


flattenTexts : List HtmlNode -> List String
flattenTexts children =
  children
    |> List.map (\child ->
      case child of
        Element n ->
          flattenTexts n.children
        Text text ->
          [ text ]
    )
    |> List.concat
