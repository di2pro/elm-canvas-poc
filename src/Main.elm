port module Main exposing (..)

import Browser
import Canvas exposing (clear)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Process
import Task


main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


port wsPub : String -> Cmd msg


port wsSub : (String -> msg) -> Sub msg


type Model
    = Loading
    | GotSettings UserSettings
    | FetchingPlayerSettings UserSettings
    | GotPlayerSettings UserSettings PlayerSettings
    | StartedSharing UserSettings PlayerSettings Player
    | Error Reason


type alias Reason =
    String


type alias UserSettings =
    { role : UserRole
    , availableTechnologies : TechStack
    }


type alias PlayerSettings =
    { technology : TechName
    , isMobile : Bool
    , screens : List Screen
    , windows : List Screen
    , popUpMenu : PopUpMenu
    }


type alias Player =
    { screen : Screen
    , state : PlayerState
    }


type PlayerState
    = Started
    | Stopped
    | Paused


type PopUpMenu
    = Hidden
    | Screens
    | Windows


type alias Screen =
    { title : String
    , id : String
    }


type UserRole
    = Presenter
    | Participant


type alias TechStack =
    List TechName


type alias TechName =
    String


init : () -> ( Model, Cmd Msg )
init _ =
    ( Loading
    , initConference
    )


type Msg
    = SendMessage String
    | ReceiveMessage String
    | GetSettings UserSettings
    | FetchPlayerSettings
    | ChangePopUpMenu PopUpMenu
    | GetPlayerSettings PlayerSettings
    | StartSharing Player
    | ChangePlayerState PlayerState
    | SelectScreen Screen


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model ) of
        ( SendMessage data, _ ) ->
            ( model, wsPub data )

        ( ReceiveMessage _, _ ) ->
            ( model, Cmd.none )

        ( GetSettings userSettings, Loading ) ->
            ( GotSettings userSettings, Cmd.none )

        ( FetchPlayerSettings, GotSettings userSettings ) ->
            ( FetchingPlayerSettings userSettings, fetchPlayerSettings )

        ( GetPlayerSettings playerSettings, FetchingPlayerSettings userSettings ) ->
            checkTechnologies userSettings playerSettings

        ( StartSharing player, GotPlayerSettings userSettings playerSettings ) ->
            ( StartedSharing userSettings playerSettings player, Cmd.none )

        ( ChangePopUpMenu popUpMenu, GotPlayerSettings userSettings playerSettings ) ->
            ( GotPlayerSettings userSettings (updatePopUpMenu popUpMenu playerSettings), Cmd.none )

        ( ChangePopUpMenu popUpMenu, StartedSharing userSettings playerSettings player ) ->
            ( StartedSharing userSettings (updatePopUpMenu popUpMenu playerSettings) player, Cmd.none )

        ( SelectScreen screen, GotPlayerSettings userSettings playerSettings ) ->
            startNewShareSession screen userSettings playerSettings

        ( SelectScreen screen, StartedSharing userSettings playerSettings player ) ->
            ( StartedSharing userSettings { playerSettings | popUpMenu = Hidden } (updateScreen screen player), Cmd.none )

        ( ChangePlayerState playerState, StartedSharing userSettings playerSettings player ) ->
            ( StartedSharing userSettings playerSettings { player | state = playerState }, Cmd.none )

        ( _, _ ) ->
            ( model, Cmd.none )


checkTechnologies : UserSettings -> PlayerSettings -> ( Model, Cmd Msg )
checkTechnologies userSettings playerSettings =
    case ( userSettings.role, playerSettings.technology ) of
        ( Presenter, "VNC" ) ->
            case playerSettings.isMobile of
                True ->
                    ( StartedSharing userSettings playerSettings { screen = { id = "2", title = "Mobile Screen" }, state = Started }, Cmd.none )

                False ->
                    ( GotPlayerSettings userSettings playerSettings, Cmd.none )

        ( Presenter, "WebRTC" ) ->
            ( GotPlayerSettings userSettings playerSettings, Cmd.none )

        ( Participant, _ ) ->
            ( StartedSharing userSettings playerSettings { screen = { id = "1", title = "" }, state = Started }, Cmd.none )

        ( _, _ ) ->
            ( GotPlayerSettings userSettings playerSettings, Cmd.none )


startNewShareSession : Screen -> UserSettings -> PlayerSettings -> ( Model, Cmd Msg )
startNewShareSession screen userSettings playerSettings =
    ( StartedSharing userSettings { playerSettings | popUpMenu = Hidden } { screen = screen, state = Started }, Cmd.none )


updatePopUpMenu : PopUpMenu -> PlayerSettings -> PlayerSettings
updatePopUpMenu popUpMenu playerSettings =
    { playerSettings | popUpMenu = popUpMenu }


updateScreen : Screen -> Player -> Player
updateScreen screen player =
    { player | screen = screen }


view : Model -> Html Msg
view model =
    case model of
        Loading ->
            div [ class "flex-grow-1 d-flex flex-column justify-content-center align-items-center" ]
                [ text "Loading ..." ]

        Error reason ->
            div [ class "flex-grow-1 d-flex flex-column justify-content-center align-items-center" ]
                [ text "Something went wrong", text reason ]

        GotSettings userSettings ->
            case userSettings.role of
                Presenter ->
                    div [ class "flex-grow-1 d-flex flex-column justify-content-center align-items-center" ]
                        [ button [ class "btn btn-success", onClick FetchPlayerSettings ] [ text "Start Sharing" ] ]

                Participant ->
                    div [ class "flex-grow-1 d-flex flex-column justify-content-center align-items-center" ]
                        [ text "Connecting..." ]

        FetchingPlayerSettings userSettings ->
            case userSettings.role of
                Participant ->
                    div [ class "flex-grow-1 d-flex flex-column justify-content-center align-items-center" ]
                        [ text "Connecting..." ]

                Presenter ->
                    div [ class "flex-grow-1 d-flex flex-column justify-content-center align-items-center" ]
                        [ button [ class "btn btn-success", disabled True ] [ text "Starting ..." ] ]

        GotPlayerSettings userSettings playerSettings ->
            case userSettings.role of
                Participant ->
                    div [ class "flex-grow-1 d-flex flex-column justify-content-center align-items-center" ]
                        [ div [ class "sv-conference__container d-flex flex-column" ]
                            [ div
                                [ class "sv-conference__header d-flex justify-content-center align-items-center"
                                ]
                                []
                            , div [ class "sv-conference__canvas d-flex flex-column flex-grow-1" ]
                                []
                            , div
                                [ class "sv-conference__actions d-flex align-items-center justify-content-around" ]
                                []
                            ]
                        ]

                Presenter ->
                    case playerSettings.technology of
                        "VNC" ->
                            case playerSettings.isMobile of
                                True ->
                                    div [ class "flex-grow-1 d-flex flex-column justify-content-center align-items-center" ]
                                        [ button [ class "btn btn-success", disabled True ] [ text "Starting ..." ] ]

                                False ->
                                    div [ class "flex-grow-1 d-flex flex-column justify-content-center align-items-center" ]
                                        [ div [ class "sv-conference__container d-flex flex-column" ]
                                            [ div
                                                [ class "sv-conference__header d-flex justify-content-center align-items-center"
                                                ]
                                                []
                                            , div [ class "sv-conference__canvas d-flex flex-column flex-grow-1" ]
                                                []
                                            , div
                                                [ class "sv-conference__actions d-flex align-items-center justify-content-around" ]
                                                [ button [ class "btn btn-outline-primary", onClick (ChangePopUpMenu Screens) ] [ text "Select Screen" ]
                                                , button [ class "btn btn-outline-primary", onClick (ChangePopUpMenu Windows) ] [ text "Select Window" ]
                                                ]
                                            ]
                                        , popUpMenuView playerSettings.popUpMenu playerSettings
                                        ]

                        "WebRTC" ->
                            div [ class "flex-grow-1 d-flex flex-column justify-content-center align-items-center" ]
                                [ div [ class "sv-conference__container d-flex flex-column" ]
                                    [ div
                                        [ class "sv-conference__header d-flex justify-content-center align-items-center"
                                        ]
                                        []
                                    , div [ class "sv-conference__canvas d-flex flex-column flex-grow-1" ]
                                        []
                                    , div
                                        [ class "sv-conference__actions d-flex align-items-center justify-content-around" ]
                                        [ button [ class "btn btn-outline-primary", onClick (ChangePopUpMenu Screens) ] [ text "Select Screen" ] ]
                                    ]
                                , popUpMenuView playerSettings.popUpMenu playerSettings
                                ]

                        _ ->
                            div [ class "flex-grow-1 d-flex flex-column justify-content-center align-items-center" ]
                                [ p [] [ text "Got an error, try to reload" ] ]

        StartedSharing userSettings playerSettings player ->
            case userSettings.role of
                Participant ->
                    div [ class "flex-grow-1 d-flex flex-column justify-content-center align-items-center" ]
                        [ div [ class "sv-conference__container d-flex flex-column" ]
                            [ div
                                [ class "sv-conference__header d-flex justify-content-center align-items-center"
                                ]
                                [ h5 [ class "sv-conference__title m-0" ] [ text player.screen.title ]
                                ]
                            , div [ class "sv-conference__canvas d-flex flex-column flex-grow-1" ]
                                [ canvasView player.state
                                ]
                            , div
                                [ class "sv-conference__actions d-flex align-items-center justify-content-around" ]
                                []
                            ]
                        ]

                Presenter ->
                    case playerSettings.technology of
                        "VNC" ->
                            case playerSettings.isMobile of
                                True ->
                                    div [ class "flex-grow-1 d-flex flex-column justify-content-center align-items-center" ]
                                        [ div [ class "sv-conference__container d-flex flex-column" ]
                                            [ div
                                                [ class "sv-conference__header d-flex justify-content-center align-items-center"
                                                ]
                                                [ h5 [ class "sv-conference__title m-0" ] [ text player.screen.title ]
                                                ]
                                            , div [ class "sv-conference__canvas d-flex flex-column flex-grow-1" ]
                                                [ canvasView player.state
                                                ]
                                            , div
                                                [ class "sv-conference__actions d-flex align-items-center justify-content-around" ]
                                                [ playPauseBtnView player.state ]
                                            ]
                                        ]

                                False ->
                                    div [ class "flex-grow-1 d-flex flex-column justify-content-center align-items-center" ]
                                        [ div [ class "sv-conference__container d-flex flex-column" ]
                                            [ div
                                                [ class "sv-conference__header d-flex justify-content-center align-items-center"
                                                ]
                                                [ h5 [ class "sv-conference__title m-0" ] [ text player.screen.title ]
                                                ]
                                            , div [ class "sv-conference__canvas d-flex flex-column flex-grow-1" ]
                                                [ canvasView player.state
                                                ]
                                            , div
                                                [ class "sv-conference__actions d-flex align-items-center justify-content-around" ]
                                                [ button [ class "btn btn-outline-primary", onClick (ChangePopUpMenu Screens) ] [ text "Select Screen" ]
                                                , button [ class "btn btn-outline-primary", onClick (ChangePopUpMenu Windows) ] [ text "Select Window" ]
                                                , playPauseBtnView player.state
                                                ]
                                            ]
                                        , popUpMenuView playerSettings.popUpMenu playerSettings
                                        ]

                        "WebRTC" ->
                            div [ class "flex-grow-1 d-flex flex-column justify-content-center align-items-center" ]
                                [ div [ class "sv-conference__container d-flex flex-column" ]
                                    [ div
                                        [ class "sv-conference__header d-flex justify-content-center align-items-center"
                                        ]
                                        [ h5 [ class "sv-conference__title m-0" ] [ text player.screen.title ]
                                        ]
                                    , div [ class "sv-conference__canvas d-flex flex-column flex-grow-1" ]
                                        [ canvasView player.state ]
                                    , div
                                        [ class "sv-conference__actions d-flex align-items-center justify-content-around" ]
                                        [ button [ class "btn btn-outline-primary", onClick (ChangePopUpMenu Screens) ] [ text "Select Screen" ]
                                        , playPauseBtnView player.state
                                        ]
                                    ]
                                , popUpMenuView playerSettings.popUpMenu playerSettings
                                ]

                        _ ->
                            div [ class "flex-grow-1 d-flex flex-column justify-content-center align-items-center" ]
                                [ p [] [ text "Got an error, try to reload" ] ]


popUpMenuView : PopUpMenu -> PlayerSettings -> Html Msg
popUpMenuView popUpMenu playerSettings =
    case ( popUpMenu, playerSettings.technology ) of
        ( Hidden, _ ) ->
            div [ class "modal" ] []

        ( Screens, "VNC" ) ->
            div [ class "modal modal--shown" ]
                [ div [ class "modal-dialog" ]
                    [ div [ class "modal-content" ]
                        [ div [ class "modal-header" ]
                            [ ul [ class "nav nav-pills" ]
                                [ li [ class "nav-item" ]
                                    [ a
                                        [ class "nav-link active"
                                        , href "#"
                                        , onClick (ChangePopUpMenu Screens)
                                        ]
                                        [ text "Screens" ]
                                    ]
                                , li [ class "nav-item" ]
                                    [ a
                                        [ class "nav-link"
                                        , href "#"
                                        , onClick (ChangePopUpMenu Windows)
                                        ]
                                        [ text "Windows" ]
                                    ]
                                ]
                            , button
                                [ class "btn btn-light"
                                , onClick (ChangePopUpMenu Hidden)
                                ]
                                [ text "close" ]
                            ]
                        , div [ class "modal-body" ]
                            [ screensView playerSettings.screens
                            ]
                        ]
                    ]
                ]

        ( Windows, "VNC" ) ->
            div [ class "modal modal--shown" ]
                [ div [ class "modal-dialog" ]
                    [ div [ class "modal-content" ]
                        [ div [ class "modal-header" ]
                            [ ul [ class "nav nav-pills" ]
                                [ li [ class "nav-item" ]
                                    [ a
                                        [ class "nav-link"
                                        , href "#"
                                        , onClick (ChangePopUpMenu Screens)
                                        ]
                                        [ text "Screens" ]
                                    ]
                                , li [ class "nav-item" ]
                                    [ a
                                        [ class "nav-link active"
                                        , href "#"
                                        , onClick (ChangePopUpMenu Windows)
                                        ]
                                        [ text "Windows" ]
                                    ]
                                ]
                            , button
                                [ class "btn btn-light"
                                , onClick (ChangePopUpMenu Hidden)
                                ]
                                [ text "close" ]
                            ]
                        , div [ class "modal-body" ]
                            [ screensView playerSettings.windows
                            ]
                        ]
                    ]
                ]

        ( _, "WebRTC" ) ->
            div [ class "modal modal--shown" ]
                [ div [ class "modal-dialog" ]
                    [ div [ class "modal-content" ]
                        [ div [ class "modal-header" ]
                            [ button
                                [ class "btn btn-light"
                                , onClick (ChangePopUpMenu Hidden)
                                ]
                                [ text "close" ]
                            ]
                        , div [ class "modal-body" ]
                            [ screensView playerSettings.screens
                            ]
                        ]
                    ]
                ]

        ( _, _ ) ->
            div [ class "modal" ] []


screensView : List Screen -> Html Msg
screensView screens =
    screens
        |> List.map (\screen -> button [ class "list-group-item list-group-item-action", onClick (SelectScreen screen) ] [ text screen.title ])
        |> div [ class "list-group" ]


playPauseBtnView : PlayerState -> Html Msg
playPauseBtnView playerState =
    case playerState of
        Started ->
            button [ class "btn btn-outline-secondary", onClick (ChangePlayerState Paused) ] [ text "Pause" ]

        Paused ->
            button [ class "btn btn-outline-secondary", onClick (ChangePlayerState Started) ] [ text "Play" ]

        Stopped ->
            button [ class "d-none" ] []


canvasView : PlayerState -> Html msg
canvasView playerState =
    case playerState of
        Started ->
            div [ class "sv-canvas flex-grow-1" ]
                [ Canvas.toHtml ( 500, 400 )
                    [ style "border-radius" "4px" ]
                    [ clear ( 0, 0 ) 500 400 ]
                ]

        _ ->
            text ""


subscriptions : Model -> Sub Msg
subscriptions _ =
    wsSub ReceiveMessage


initConference : Cmd Msg
initConference =
    Process.sleep 1000
        |> Task.perform (\_ -> GetSettings <| UserSettings Presenter [ "VNC", "WebRTC" ])


fetchPlayerSettings : Cmd Msg
fetchPlayerSettings =
    Process.sleep 1000
        |> Task.perform (\_ -> GetPlayerSettings <| PlayerSettings "VNC" False [ Screen "Main" "M", Screen "Second" "S" ] [] Hidden)
