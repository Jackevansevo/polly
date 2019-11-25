module Update exposing (update)

import Array
import Browser
import Browser.Navigation as Nav
import Cmds exposing (createPoll, fetchPoll)
import Model exposing (Model, Option, Page(..), PollForm, PollState(..), Selection(..), Vote(..))
import Msgs exposing (Msg(..))
import Ports exposing (requestToken)
import Routing
import Set
import Url
import Url.Builder as Builder


removeFromList : Int -> List a -> List a
removeFromList i xs =
    List.take i xs ++ List.drop (i + 1) xs


removeFromArray : Int -> Array.Array a -> Array.Array a
removeFromArray i =
    Array.toList >> removeFromList i >> Array.fromList


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model.page ) of
        ( ChangeTitle newTitle, Creating pollForm ) ->
            ( { model | page = Creating { pollForm | title = newTitle } }, Cmd.none )

        ( DeleteFormRow index, Creating pollForm ) ->
            let
                newOptions =
                    removeFromArray index pollForm.options

                newPoll =
                    { pollForm | options = newOptions }
            in
            ( { model | page = Creating newPoll }, Cmd.none )

        ( AddFormRow, Creating pollForm ) ->
            let
                lastRow =
                    Array.get (Array.length pollForm.options - 2) pollForm.options
            in
            case lastRow of
                Just opt ->
                    let
                        newOptions =
                            Array.push (Option "" Nothing) pollForm.options

                        newPoll =
                            { pollForm | options = newOptions }
                    in
                    if String.isEmpty opt.name then
                        ( model, Cmd.none )

                    else
                        ( { model | page = Creating newPoll }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        ( ToggleMultiple, Creating pollForm ) ->
            let
                newPoll =
                    { pollForm | multi = not pollForm.multi }
            in
            ( { model | page = Creating newPoll }, Cmd.none )

        ( CreatedPoll result, _ ) ->
            case result of
                Ok pid ->
                    let
                        newRoute =
                            Routing.Poll pid

                        newUrl =
                            Builder.relative [ "poll", pid ] []
                    in
                    ( { model | route = newRoute }, Nav.pushUrl model.key newUrl )

                Err _ ->
                    ( model, Cmd.none )

        ( CreatePoll token, Creating poll ) ->
            ( model, createPoll poll token )

        ( GotPoll result, _ ) ->
            case result of
                Ok poll ->
                    let
                        pollStatus =
                            if poll.voted then
                                Voting (Success poll Submitted)

                            else
                                Voting (Success poll NotVoted)
                    in
                    ( { model | page = pollStatus }, Cmd.none )

                Err err ->
                    ( { model | page = Voting Failure }, Cmd.none )

        ( ChangeOption index val, Creating poll ) ->
            let
                updateOption pos option =
                    if pos == index then
                        { option | name = val }

                    else
                        option

                newOptions =
                    Array.indexedMap updateOption poll.options

                updatedPoll =
                    { poll | options = newOptions }
            in
            ( { model | page = Creating updatedPoll }, Cmd.none )

        ( SubmitVote token option, Voting (Success poll _) ) ->
            ( model, Cmds.submitVote poll.pid token option )

        ( Voted result, Voting (Success poll _) ) ->
            case result of
                Ok _ ->
                    ( { model | page = Voting (Success poll Submitted) }, fetchPoll poll.pid )

                Err err ->
                    ( { model | page = Voting (Success poll (Failed err)) }, Cmd.none )

        ( SelectOption selected, Voting (Success poll vote) ) ->
            case poll.selection of
                Single _ ->
                    let
                        newPoll =
                            { poll | selection = Single (Just selected) }
                    in
                    ( { model | page = Voting (Success newPoll vote) }, Cmd.none )

                Multi vals ->
                    if Set.member selected vals then
                        let
                            newSet =
                                Set.remove selected vals

                            newPoll =
                                { poll | selection = Multi newSet }
                        in
                        ( { model | page = Voting (Success newPoll vote) }, Cmd.none )

                    else
                        let
                            newSet =
                                Set.insert selected vals

                            newPoll =
                                { poll | selection = Multi newSet }
                        in
                        ( { model | page = Voting (Success newPoll vote) }, Cmd.none )

        ( RefreshToken time, _ ) ->
            ( model , requestToken "home" )

        ( LinkClicked urlRequest, _ ) ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        ( UrlChanged url, _ ) ->
            let
                newRoute =
                    Routing.fromUrl url
            in
            case newRoute of
                Routing.Home ->
                    let
                        emptyOptions =
                            Array.repeat 3 { name = "", error = Nothing }
                    in
                    ( { model
                        | url = url
                        , page = Creating (PollForm "" emptyOptions False Nothing)
                        , route = newRoute
                      }
                    , requestToken "home"
                    )

                Routing.Poll pid ->
                    ( { model | url = url, route = newRoute, page = Voting Loading }
                    , Cmd.batch [ fetchPoll pid, requestToken "vote" ]
                    )

                Routing.NotFound ->
                    ( { model | page = NotFoundPage }, Cmd.none )

        ( GotToken token, _ ) ->
            ( { model | token = Just token }, Cmd.none )

        ( _, _ ) ->
            ( model, Cmd.none )
