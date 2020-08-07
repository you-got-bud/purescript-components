module Components.Button where

import Prelude

import Data.Maybe (Maybe)
import Effect (Effect)
import React.Basic (JSX, ReactComponent, Self, createComponent, makeStateless)
import React.Basic as React
import React.Basic.Compat (Component)
import React.Basic.DOM as DOM
import React.Basic.DOM.Events as DOM.Events
import React.Basic.Events (EventHandler)


data ButtonColor = Primary | Secondary
data ButtonType = IconButton | LargeButton ButtonColor | NormalButton

type Props = {
    -- | Either when the button is focused and the user presses 
    -- | the enter key or clicks on the button
    onEnter :: EventHandler,
    type :: ButtonType
}

largeButtonClassName :: String
largeButtonClassName = "mx-24"

-- TODO: Use stronger classname type
-- TODO: Have base className
buttonClassName :: ButtonType -> String
buttonClassName IconButton = "mx-12"
buttonClassName (LargeButton Primary) = largeButtonClassName <> "bg-green-400"
buttonClassName (LargeButton Secondary) = largeButtonClassName <> "bg-yellow-400"
buttonClassName NormalButton = "mx-12 appearance-none"
buttonClassName _ = "mx-12"


type State = {
    -- | When the button is hovered or focused
    isSelected :: Boolean
}

component = createComponent "Button"

button :: Props -> JSX
button = makeStateless component render

data Action = Focus | Hover | KeyDown (Maybe String) | Click
type SetState = (State -> State) -> Effect Unit


render :: Self Props State
render self@{state, props}  = DOM.button { className: buttonClassName props.type }
    where React.runUpdate \_self ->
        case _ of
            Focus -> Update (self.state { isSelected = true })
            Hover -> Update (self.state { isSelected = true })
