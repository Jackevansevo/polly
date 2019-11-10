module Msgs exposing (Msg(..))

import Browser
import Json.Encode as E
import Http
import Model exposing (Poll)
import Url


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | ChangeOption Int String
    | ChangeTitle String
    | CreatePoll String
    | GotPoll (Result Http.Error Poll)
    | CreatedPoll (Result Http.Error String)
    | SelectOption String
    | SubmitVote String (List String)
    | Voted (Result Http.Error ())
    | AddFormRow
    | DeleteFormRow Int
    | NoOp
    | ToggleMultiple
    | Searched String
    | GotToken String
