module View exposing (view)

import Browser
import Html exposing (text)
import Model exposing (Model, Page(..), PollState(..))
import Msgs exposing (Msg(..))
import Views.Create exposing (createView)
import Views.Vote exposing (viewPoll)


view : Model -> Browser.Document Msg
view model =
    case model.page of
        Creating poll ->
            createView poll model.token

        Voting viewing ->
            viewPoll viewing model.token

        NotFoundPage ->
            { title = "Not Found", body = [ text "Not Found" ] }
