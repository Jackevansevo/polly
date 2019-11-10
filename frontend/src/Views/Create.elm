module Views.Create exposing (createView, createViewForm)

import Array
import Browser
import Html exposing (Html, button, div, h1, i, input, label, legend, text)
import Html.Attributes exposing (autocomplete, autofocus, checked, class, disabled, for, id, placeholder, required, tabindex, type_, value)
import Html.Events exposing (onBlur, onClick, onFocus, onInput, onSubmit)
import Model exposing (PollForm)
import Msgs exposing (Msg(..))
import Views.Base exposing (baseView)


createView : PollForm -> Maybe String -> Browser.Document Msg
createView poll token =
    { title = "Creating a poll"
    , body =
        [ baseView [ createViewForm poll token ] ]
    }


createViewForm : PollForm -> Maybe String -> Html Msg
createViewForm poll token =
    let
        lastIndex =
            Array.length poll.options - 1

        nonEmpty =
            Array.filter (\x -> not (String.isEmpty x.name)) poll.options

        disableSubmit =
            Array.length nonEmpty <= 1 && (String.isEmpty (Maybe.withDefault "" token))

        canRemove =
            Array.length poll.options < 3

        submitButton =
            button
                [ class "btn btn-success"
                , disabled disableSubmit
                , type_ "submit"
                ]
                [ text "Create" ]

        optionInput index opt =
            let
                onFocusEvent =
                    if index == lastIndex then
                        onFocus AddFormRow

                    else
                        onFocus NoOp

                onBlurEvent =
                    if index == lastIndex - 1 && String.isEmpty opt.name && Array.length poll.options > 3 then
                        onBlur (DeleteFormRow lastIndex)

                    else
                        onBlur NoOp

                placeholderValue =
                    "Option " ++ String.fromInt (index + 1)
            in
            div [ class "col-12" ]
                [ div [ class "input-group py-1" ]
                    [ input
                        [ value opt.name
                        , class "form-input"
                        , onInput (ChangeOption index)
                        , onFocusEvent
                        , onBlurEvent
                        , placeholder placeholderValue
                        , Html.Attributes.maxlength 40
                        ]
                        []
                    , button
                        [ class "btn btn-error input-group-btn"
                        , tabindex -1
                        , type_ "button"
                        , onClick (DeleteFormRow index)
                        , disabled canRemove
                        ]
                        [ i [ class "icon icon-cross" ] [] ]
                    ]
                ]
    in
    Html.form
        [ class "form-horizontal", onSubmit (CreatePoll (Maybe.withDefault "" token)) ]
        [ legend [] [ h1 [] [ text "Create Poll" ] ]
        , div [ class "form-group" ]
            [ label [ class "form-label", type_ "text", for "title-input" ] [ text "Title" ]
            , input
                [ class "form-input py-1"
                , required True
                , type_ "text"
                , autocomplete False
                , value poll.title
                , onInput ChangeTitle
                , autofocus True
                , id "title-input"
                , placeholder "Title"
                ]
                []
            ]
        , div [ class "form-label" ] [ text "Options" ]
        , div [ class "form-group" ]
            (Array.toList (Array.indexedMap optionInput poll.options))
        , div [ class "form-group" ]
            [ label [ class "form-switch" ]
                [ input
                    [ type_ "checkbox"
                    , onClick ToggleMultiple
                    , checked poll.multi
                    ]
                    []
                , i [ class "form-icon" ] []
                , text "Allow multiple votes"
                ]
            ]
        , submitButton
        ]
