import 'video.js/dist/video-js.min.css'
import * as React from "react"
import {
    ChakraProvider,
    Box,
    Stack,
    Button,
    Heading,
    Container,
    Grid,
    Text,
    theme
} from "@chakra-ui/react"
import { FaCamera, FaTimes, FaPlay } from "react-icons/fa"
import { Socket, Channel } from "phoenix"
import { useQuery, gql } from "@apollo/client"
import { env } from "./constants"
import client from "./client"
import ColorModeSwitcher from './components/color_mode_switcher'
import { Helmet } from "react-helmet"
import videojs from "video.js"
import "videojs-vtt-thumbnails"
import "@videojs/http-streaming"

const GET_TRANSMISSIONS = gql`
  query {
    transmissions {
      uuid
      name
    }
  }
`

export const App = () => {
    const { data } = useQuery(GET_TRANSMISSIONS, {
        client
    })
    const [transmission, setTransmission] = React.useState<Transmission | null>()

    const [isPlaying, setPlaying] = React.useState<boolean>(false)
    const videoRef = React.useRef<HTMLMediaElement>(null) as React.RefObject<HTMLVideoElement>
    const channel = React.useRef<Channel>()
    const stream = React.useRef<MediaStream>()
    const socket = React.useMemo(() => new Socket(`${env?.WS_API_HOST}/socket`), [])

    socket.onError(() => console.log("there was an error with the connection!"))
    socket.onClose(() => console.log("the connection dropped"))

    const onTransmissionPlay = (transmission: Transmission) => () => {
        setTransmission(transmission)
    }

    const onDataAvailable = ({ data }: BlobEvent) => {
        const reader = new FileReader()
        reader.onloadend = () => {
            channel.current?.push("segment", { data: reader.result })
        }

        reader.readAsDataURL(data)
    }

    const onLoadedMetaData = (stream: MediaStream) => () => {
        const video = videoRef.current
        if (video) {
            video.play()
            const mediaRecorder = new MediaRecorder(stream, {
                mimeType: 'video/webm',
                videoBitsPerSecond: 3000000
            })

            mediaRecorder.ondataavailable = onDataAvailable
            mediaRecorder.start(1000)
        }
    }

    const onClick = async () => {
        if (isPlaying && stream.current) {
            stream.current.getTracks().forEach(track => track.stop())
            channel.current?.push("stop", {})
        } else {
            setTransmission(null)
            channel.current?.push("start", {})

            const constraints = {
                audio: false,
                video: true
            }

            if (!socket.isConnected()) {
                socket.connect()
            }

            try {
                stream.current = await navigator.mediaDevices.getUserMedia(constraints)
                const video = videoRef.current
                if (video) {
                    video.srcObject = stream.current
                    video.onloadedmetadata = onLoadedMetaData(stream.current)
                }
            } catch (error) {
                console.warn(error)
            }
        }

        setPlaying(!isPlaying)
    }

    React.useEffect(() => {
        if (!channel.current) {
            channel.current = socket.channel("transmit:video")
            channel.current.onError(() => console.error("there was an error!"))
            channel.current.onClose(() => {
                setPlaying(false)
                console.warn("the channel has gone away gracefully")
            })
            channel.current
                .join()
                .receive("ok", (response) => console.info(response))
                .receive("error", (response) => console.error(response))
        }
        return socket.disconnect()
    }, [socket])

    React.useEffect(() => {
        const player = videojs(videoRef.current, {
            liveui: false,
            errorDisplay: false
        })

        if (transmission && player) {
            const srcConfig = {
                src: `${env?.HTTP_API_HOST}/transmissions/${transmission.uuid}/index.m3u8`,
                type: "application/x-mpegURL"
            }
            const thumbnailsConfig = {
                src: `${env?.HTTP_API_HOST}/transmissions/${transmission.uuid}/thumbnails.vtt`,
                showTimestamp: true
            }

            player.ready(() => {
                player.src(srcConfig)
                player.vttThumbnails(thumbnailsConfig)
                player.play()
            })

            player.on('error', () => {
                // player.createModal('Retrying connection')
                if (player.error().code === 4) {
                    player.retryLock = setTimeout(() => {
                        player.src(srcConfig)
                        player.load()
                    }, 1000)
                }
            })
        }
    }, [transmission])

    return (
        <ChakraProvider theme={theme}>
            <Helmet>
                <style type="text/css">{`
          .vjs-default-skin.vjs-paused .vjs-big-play-button {
            display: none;
          }
          
          .video-js .vjs-big-play-button {
            display: none;
          }
        `}</style>
            </Helmet>
            <Box textAlign="center" fontSize="xl">
                <Grid minH="80vh" p={3}>
                    <ColorModeSwitcher justifySelf="flex-end" />
                    <Container centerContent>
                        <video className="video-js" controls ref={videoRef} width={640} height={360} />
                        <Button onClick={onClick} colorScheme={isPlaying ? "red" : "blue"} rightIcon={isPlaying ? <FaTimes /> : <FaCamera />}>
                            {isPlaying ? "Stop" : "Start"}
                        </Button>
                    </Container>
                </Grid>
            </Box>
            <Box>
                <Heading>Previous Transmissions</Heading>
                <Stack spacing={4} direction="row" align="center">
                    {data?.list_transmissions.map(
                        (transmission: Transmission, key: number) => <Box key={key}>
                            <Text>
                                {transmission.uuid}
                            </Text>
                            <Button rightIcon={<FaPlay />} onClick={onTransmissionPlay(transmission)} colorScheme="red">
                                Play
              </Button>
                        </Box>
                    )}
                </Stack>
            </Box>
        </ChakraProvider >
    )
}


