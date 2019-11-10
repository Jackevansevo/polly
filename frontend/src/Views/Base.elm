module Views.Base exposing (baseView)

import Html exposing (Html, a, div, header, section, text)
import Html.Attributes exposing (class, href, style)
import Msgs exposing (Msg(..))


baseView : List (Html Msg) -> Html Msg
baseView content =
    div [ class "container grid-xs" ]
        [ header [ class "header", style "margin-bottom" "1rem" ]
            [ section [ class "navbar-section pt-2" ]
                [ a [ href "/", class "btn btn-link" ] [ text "Home" ]
                ]
            ]
        , section [] content
        ]
