port module Main exposing (..)

import Browser
import Canvas exposing (clear)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as Decode
import Json.Decode.Pipeline as DecodePipeline


main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


port wsPub : String -> Cmd msg


port wsSub : (String -> msg) -> Sub msg


type alias Model =
    { modalState : ModalState
    , conferenceState : ConferenceState
    , conferenceTitle : String
    , user : User
    , agent : Agent
    }


type Agent
    = Desktop
    | Mobile


type ModalState
    = Hidden
    | Screens
    | Windows


type ConferenceState
    = Shared
    | Stopped
    | Closed


type User
    = Guest
    | Presenter
    | Participant


init : () -> ( Model, Cmd Msg )
init _ =
    ( Model Hidden Closed "" Presenter Desktop, Cmd.none )


type Msg
    = MessagePrepared String
    | MessageReceived String
    | ModalStateUpdated ModalState
    | ConferenceUpdated ConferenceState


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        MessagePrepared data ->
            ( model, wsPub data )

        MessageReceived _ ->
            ( model, Cmd.none )

        ModalStateUpdated state ->
            ( { model | modalState = state }, Cmd.none )

        ConferenceUpdated state ->
            ( { model | conferenceState = state }, Cmd.none )


view : Model -> Html Msg
view model =
    case model.user of
        Presenter ->
            div [ class "flex-grow-1 d-flex flex-column justify-content-center align-items-center" ]
                [ div [ class "sv-conference__container d-flex flex-column" ]
                    [ div
                        [ class "sv-conference__header d-flex justify-content-center align-items-center"
                        ]
                        [ h5 [ class "sv-conference__title m-0" ] [ text model.conferenceTitle ]
                        ]
                    , div [ class "sv-conference__canvas d-flex flex-column flex-grow-1" ]
                        [ div [ class "sv-canvas flex-grow-1" ]
                            [ Canvas.toHtml ( 500, 400 )
                                [ style "border-radius" "4px" ]
                                [ clear ( 0, 0 ) 500 400 ]
                            ]
                        , div
                            [ classList
                                [ ( "sv-conference__overflow-actions", True )
                                , ( "flex-column align-items-center justify-content-center", True )
                                , ( "d-flex", model.conferenceState /= Shared )
                                , ( "d-none", model.conferenceState == Shared )
                                ]
                            ]
                            [ button
                                [ classList
                                    [ ( "btn btn-success", True )
                                    , ( "d-block", model.conferenceState == Closed )
                                    , ( "d-none", model.conferenceState /= Closed )
                                    ]
                                , onClick (ConferenceUpdated Shared)
                                ]
                                [ text "Share Screen" ]
                            ]
                        ]
                    , div
                        [ class "sv-conference__actions d-flex align-items-center justify-content-around" ]
                        (conferenceActions model.conferenceState)
                    ]
                , div
                    [ classList
                        [ ( "modal", True )
                        , ( "modal--shown", model.modalState /= Hidden )
                        ]
                    , tabindex -1
                    ]
                    [ div [ class "modal-dialog modal-dialog-centered" ]
                        [ div [ class "modal-content" ]
                            [ div [ class "modal-header d-flex justify-content-between" ]
                                [ div [ class "btn-group" ]
                                    [ button
                                        [ classList
                                            [ ( "btn btn-outline-primary", True )
                                            , ( "btn-primary text-white", model.modalState == Screens )
                                            ]
                                        , onClick (ModalStateUpdated Screens)
                                        ]
                                        [ text "Screens" ]
                                    , button
                                        [ classList
                                            [ ( "btn btn-outline-primary", True )
                                            , ( "btn-primary text-white", model.modalState == Windows )
                                            ]
                                        , onClick (ModalStateUpdated Windows)
                                        ]
                                        [ text "Windows" ]
                                    ]
                                , button
                                    [ class "btn btn-sm btn-light"
                                    , onClick (ModalStateUpdated Hidden)
                                    ]
                                    [ text "Close" ]
                                ]
                            , modalView model.modalState
                            ]
                        ]
                    ]
                ]

        Participant ->
            div [ class "flex-grow-1 d-flex flex-column justify-content-center align-items-center" ]
                [ div [ class "sv-conference__container d-flex flex-column" ]
                    [ div
                        [ class "sv-conference__header d-flex justify-content-center align-items-center"
                        ]
                        [ h5 [ class "sv-conference__title m-0" ] [ text model.conferenceTitle ]
                        ]
                    , div [ class "sv-conference__canvas d-flex flex-column flex-grow-1" ]
                        [ div [ class "sv-canvas flex-grow-1" ]
                            [ Canvas.toHtml ( 500, 400 )
                                [ style "border-radius" "4px" ]
                                [ clear ( 0, 0 ) 500 400 ]
                            ]
                        ]
                    , div
                        [ class "sv-conference__actions d-flex align-items-center justify-content-around" ]
                        []
                    ]
                ]

        Guest ->
            div [] []


conferenceActions : ConferenceState -> List (Html Msg)
conferenceActions state =
    case state of
        Closed ->
            []

        Shared ->
            [ button
                [ class "btn btn-primary"
                , onClick (ModalStateUpdated Screens)
                ]
                [ text "Select Screen" ]
            , button
                [ class "btn btn-primary"
                , onClick (ModalStateUpdated Windows)
                ]
                [ text "Select Window" ]
            , button
                [ class "btn btn-primary"
                , onClick (ConferenceUpdated Stopped)
                ]
                [ text "Pause Sharing" ]
            , button
                [ class "btn btn-warning"
                , onClick (ConferenceUpdated Closed)
                ]
                [ text "Stop Sharing" ]
            ]

        Stopped ->
            [ button
                [ class "btn btn-primary"
                , onClick (ModalStateUpdated Screens)
                ]
                [ text "Select Screen" ]
            , button
                [ class "btn btn-primary"
                , onClick (ModalStateUpdated Windows)
                ]
                [ text "Select Window" ]
            , button
                [ class "btn btn-primary"
                , onClick (ConferenceUpdated Shared)
                ]
                [ text "Continue sharing" ]
            , button
                [ class "btn btn-warning"
                , onClick (ConferenceUpdated Closed)
                ]
                [ text "Stop Sharing" ]
            ]


modalView : ModalState -> Html Msg
modalView state =
    case state of
        Hidden ->
            div [] []

        Screens ->
            div [ class "modal-body" ] [ text "Screens" ]

        Windows ->
            div [ class "modal-body" ] [ text "Windows" ]


subscriptions : Model -> Sub Msg
subscriptions _ =
    wsSub MessageReceived


type alias UserTypeMessage =
    { user : Int
    , stack : List String
    }


userTypeDecoder : Decode.Decoder UserTypeMessage
userTypeDecoder =
    Decode.succeed UserTypeMessage
        |> DecodePipeline.required "user" Decode.int
        |> DecodePipeline.required "stack" (Decode.list Decode.string)
