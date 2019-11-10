module Routing exposing (Route(..), fromUrl, toRoute)

import Url
import Url.Parser as Parser exposing ((</>), Parser, map, oneOf, parse, s, string, top)


type Route
    = Home
    | Poll String
    | NotFound


route : Parser (Route -> a) a
route =
    oneOf
        [ map Home top
        , map Poll (s "poll" </> string)
        ]


toRoute : String -> Route
toRoute string =
    case Url.fromString string of
        Nothing ->
            NotFound

        Just url ->
            Maybe.withDefault NotFound (parse route url)


fromUrl : Url.Url -> Route
fromUrl url =
    Maybe.withDefault NotFound (Parser.parse route url)
