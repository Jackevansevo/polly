module Main exposing (main)

import Time
import Array
import Browser
import Browser.Navigation as Nav
import Cmds exposing (fetchPoll)
import Json.Encode as E
import Model exposing (Model, Page(..), PollState(..))
import Msgs exposing (Msg(..))
import Routing exposing (toRoute)
import Update exposing (update)
import Url
import View exposing (view)
import Ports exposing (recieveToken, requestToken)


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }


init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    let
        route =
            toRoute (Url.toString url)
    in
    case route of
        Routing.Home ->
            let
                emptyOptions =
                    Array.repeat 3 { name = "", error = Nothing }
            in
            ( Model key
                url
                (Creating
                    { title = ""
                    , options = emptyOptions
                    , multi = False
                    , error = Nothing
                    }
                )
                route
                Nothing
            , requestToken "home"
            )

        Routing.Poll pid ->
            ( Model key url (Voting Loading) route Nothing, fetchPoll pid )

        Routing.NotFound ->
            ( Model key url NotFoundPage route Nothing, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch [Time.every (30 * 1000) RefreshToken, recieveToken GotToken]
