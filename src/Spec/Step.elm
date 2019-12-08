module Spec.Step exposing
  ( Context
  , Command
  , model
  )

{-| The scenario script is a sequence of steps. A step is a function from a `Context` to a `Command`.

See `Spec.Command`, `Spec.Markup`, `Spec.Markup.Event`, `Spec.Port`, and `Spec.Time` for
steps you can use to build your scenario script.

@docs Context, Command

# Using the Context
@docs model

-}

import Spec.Message exposing (Message)
import Spec.Step.Command as Command
import Spec.Step.Context as Context


{-| Represents the current state of the program.
-}
type alias Context model =
  Context.Context model


{-| Represents an action to be performed.
-}
type alias Command msg =
  Command.Command msg


{-| Get the current program model from the `Context`.
-}
model : Context model -> model
model =
  Context.model
