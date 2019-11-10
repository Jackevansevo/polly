module Views.Vote exposing (viewPoll)

import Browser
import Dict
import Html exposing (Html, button, div, form, h1, i, input, label, table, tbody, td, text, th, thead, tr)
import Html.Attributes exposing (checked, class, disabled, name, style, type_, value)
import Html.Events exposing (onClick, onSubmit)
import Model exposing (Poll, PollState(..), Selection(..), Vote(..))
import Msgs exposing (Msg(..))
import Set
import Views.Base exposing (baseView)


viewPoll : PollState -> Maybe String -> Browser.Document Msg
viewPoll viewing token =
    case viewing of
        Failure ->
            { title = "Viewing poll", body = [ text "Failed to load" ] }

        Loading ->
            { title = "Viewing poll", body = [ loadingView ] }

        Success poll vote ->
            let
                inputs =
                    voteInputs poll

                results =
                    if poll.voted then
                        viewResults poll.results

                    else
                        text ""

                submit =
                    case poll.selection of
                        Single (Just selected) ->
                            SubmitVote (Maybe.withDefault "" token) [ selected ]

                        Multi vals ->
                            SubmitVote (Maybe.withDefault "" token) (Set.toList vals)

                        _ ->
                            NoOp

                disableSubmit =
                    case poll.selection of
                        Single opt ->
                            case opt of
                                Just _ ->
                                    False

                                Nothing ->
                                    True

                        Multi vals ->
                            if Set.size vals == 0 then
                                True

                            else
                                False
            in
            { title = "Viewing poll"
            , body =
                [ baseView
                    [ h1 [] [ text poll.title ]
                    , voteMsg vote
                    , div [ class "divider" ] []
                    , form [ class "form py-2", onSubmit submit ]
                        [ div [ class "form-group" ]
                            [ div [] inputs
                            ]
                        , div [ class "d-flex", style "justify-content" "space-between" ]
                            [ button
                                [ class "btn btn-success my-2"
                                , disabled (disableSubmit || poll.voted)
                                ]
                                [ text "Vote" ]
                            , button
                                [ class "btn btn-primary my-2"
                                , type_ "button"
                                ]
                                [ i [ class "icon icon-link mr-2" ] [], text "Share" ]
                            ]
                        ]
                    , div [ class "divider py-2" ] []
                    , results
                    ]
                ]
            }


loadingView : Html Msg
loadingView =
    div
        [ style "display" "flex"
        , style "align-items" "center"
        , style "justify-content" "center"
        , style "height" "100vh"
        ]
        [ div [ class "loading loading-lg" ] [] ]


voteMsg : Vote -> Html Msg
voteMsg msg =
    case msg of
        NotVoted ->
            text ""

        Waiting ->
            text "voting"

        Failed _ ->
            div [ class "toast toast-error" ] [ text "Failed to submit vote" ]

        Submitted ->
            div [ class "toast toast-success" ] [ text "Voted" ]


viewResults : Dict.Dict String Int -> Html Msg
viewResults results =
    let
        resultRow ( option, votes ) =
            tr [] [ td [] [ text option ], td [] [ text (String.fromInt votes) ] ]
    in
    table [ class "table table-striped table-hover my-2" ]
        [ thead []
            [ tr []
                [ th [] [ text "Option" ]
                , th [] [ text "Votes" ]
                ]
            ]
        , tbody [] (List.map resultRow (Dict.toList results))
        ]


voteInputs : Poll -> List (Html Msg)
voteInputs poll =
    let
        inputType =
            if poll.multi then
                "checkbox"

            else
                "radio"

        formClass =
            if poll.multi then
                "form-checkbox"

            else
                "form-radio"

        isChecked opt =
            case poll.selection of
                Single (Just selected) ->
                    selected == opt

                Multi vals ->
                    Set.member opt vals

                _ ->
                    False

        voteInput opt =
            label [ class formClass ]
                [ input
                    [ type_ inputType
                    , name opt
                    , value opt
                    , onClick (SelectOption opt)
                    , checked (isChecked opt)
                    , disabled poll.voted
                    ]
                    []
                , i [ class "form-icon" ] []
                , text opt
                ]
    in
    List.map voteInput poll.options
