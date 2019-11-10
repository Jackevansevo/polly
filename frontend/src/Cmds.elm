module Cmds exposing (createPoll, fetchPoll, submitVote)

import Array
import Dict
import Http
import Json.Decode as Decode exposing (Decoder, bool, dict, field, int, list, string)
import Json.Decode.Pipeline exposing (optional, required)
import Json.Encode as Encode
import Model exposing (Poll, PollForm, Selection(..))
import Msgs exposing (Msg(..))
import Set
import String
import Url.Builder


singleDecoder : Decoder Selection
singleDecoder =
    Decode.map Single
        (Decode.map List.head
            (Decode.oneOf
                [ field "votes" (Decode.list string)
                , Decode.succeed []
                ]
            )
        )


multiDecoder : Decoder Selection
multiDecoder =
    Decode.oneOf
        [ field "votes" (Decode.list string)
            |> Decode.map Set.fromList
            |> Decode.map Multi
        , Decode.succeed <| Multi Set.empty
        ]


selectionDecoder : Bool -> Decoder Selection
selectionDecoder multi =
    if multi then
        multiDecoder

    else
        singleDecoder


pollDecoder : Decoder Poll
pollDecoder =
    Decode.succeed Poll
        |> required "pid" string
        |> required "title" string
        |> required "options" (list string)
        |> optional "results" (dict int) Dict.empty
        |> required "voted" bool
        |> required "multi" bool
        |> Json.Decode.Pipeline.custom (field "multi" bool |> Decode.andThen selectionDecoder)


fetchPoll : String -> Cmd Msg
fetchPoll pid =
    Http.get
        { url = "http://localhost:8000?pid=" ++ pid
        , expect = Http.expectJson GotPoll pollDecoder
        }


pollEncoder : PollForm -> String -> Encode.Value
pollEncoder poll token =
    let
        options =
            Array.map (String.trim << .name) poll.options

        nonEmpty =
            Array.filter (not << String.isEmpty) options
    in
    Encode.object
        [ ( "title", Encode.string poll.title )
        , ( "options", Encode.array Encode.string nonEmpty )
        , ( "multi", Encode.bool poll.multi )
        , ( "token", Encode.string token )
        ]


createPoll : PollForm -> String -> Cmd Msg
createPoll poll token =
    Http.post
        { url = "http://localhost:8000"
        , body = Http.jsonBody (pollEncoder poll token)
        , expect = Http.expectJson CreatedPoll (field "pid" string)
        }


submitVote : String -> String -> List String -> Cmd Msg
submitVote pid token options =
    let
        optionParams =
            List.map (\o -> Url.Builder.string "option" o) options

        params =
            List.append [ Url.Builder.string "pid" pid ] optionParams
    in
    Http.post
        { url = Url.Builder.crossOrigin "http://localhost:8000" [ "vote" ] params
        , body = Http.jsonBody (Encode.object [ ("token", Encode.string token) ])
        , expect = Http.expectWhatever Voted
        }
