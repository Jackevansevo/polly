module Model exposing (Model, Option, Page(..), Poll, PollForm, PollState(..), Selection(..), Vote(..))

import Array exposing (Array)
import Browser.Navigation as Nav
import Dict exposing (Dict)
import Http
import Routing exposing (Route)
import Set
import Url


type alias Option =
    { name : String
    , error : Maybe String
    }


type alias PollForm =
    { title : String
    , options : Array Option
    , multi : Bool
    , error : Maybe String
    }


type Selection
    = Single (Maybe String)
    | Multi (Set.Set String)


type alias Poll =
    { pid : String
    , title : String
    , options : List String
    , results : Dict String Int
    , voted : Bool
    , multi : Bool
    , selection : Selection
    }


type Vote
    = NotVoted
    | Failed Http.Error
    | Waiting
    | Submitted


type PollState
    = Failure
    | Loading
    | Success Poll Vote


type Page
    = Creating PollForm
    | Voting PollState
    | NotFoundPage


type alias Model =
    { key : Nav.Key
    , url : Url.Url
    , page : Page
    , route : Route
    , token: Maybe String
    }
