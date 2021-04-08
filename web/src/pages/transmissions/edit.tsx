/* eslint-disable react-hooks/exhaustive-deps */
import React from "react"
import { Code, Text, Input, FormControl, Progress, FormLabel, FormHelperText, useToast, Box, Button, Select, VStack, HStack, Container, StackDivider } from "@chakra-ui/react"
import { useParams } from "react-router-dom"
import { FaCamera, FaMicrophone, FaPlay, FaStop } from "react-icons/fa"
import { useQuery, gql } from "@apollo/client"
import { Socket, Channel } from "phoenix"
import { env } from "../../constants"
import Player from "../../components/player"
import { getToken } from '../../token'
import useUpload from "../../hooks/upload"


const GET_TRANSMISSION = gql`
  query GetTransmission($uuid: ID!) {
    transmission(uuid: $uuid) {
      uuid
      type
      name
      preview
      sprite
    }
  }
`

type TransmissionUUID = Pick<Transmission, "uuid">

interface TransmissionQuery {
  transmission: Transmission
}

const Edit: React.FC = () => {
  const toast = useToast()
  const { uuid } = useParams<TransmissionUUID>()
  const { isUploading, progress, upload } = useUpload(uuid)
  const { data } = useQuery<TransmissionQuery, TransmissionUUID>(GET_TRANSMISSION, { variables: { uuid } })
  const [devices, setDevices] = React.useState<MediaDeviceInfo[] | InputDeviceInfo[]>()
  const [audioDevices, setAudioDevices] = React.useState<InputDeviceInfo[]>([])
  const [videoDevices, setVideoDevices] = React.useState<MediaDeviceInfo[]>([])
  const [audioDevice, setAudioDevice] = React.useState<MediaDeviceInfo>()
  const [videoDevice, setVideoDevice] = React.useState<MediaDeviceInfo>()
  const [isTransmitting, setTransmitting] = React.useState<boolean>(false)
  const [isRecording] = React.useState<boolean>(true)
  const videoRef = React.useRef<HTMLMediaElement>(null) as React.RefObject<HTMLVideoElement>
  const channel = React.useRef<Channel>()
  const stream = React.useRef<MediaStream>()
  const socket = React.useRef<Socket>()

  const onDataAvailable = ({ data }: BlobEvent) => {
    const reader = new FileReader()
    reader.onloadend = () => isRecording && channel.current?.push("segment", { data: reader.result })
    reader.readAsDataURL(data)
  }

  const onLoadedMetaData = (stream: MediaStream) => () => {
    const video = videoRef.current
    if (video) {
      video.play()
      const mediaRecorder = new MediaRecorder(stream, {
        mimeType: 'video/webm;codecs=h264'
      })

      mediaRecorder.ondataavailable = onDataAvailable
      mediaRecorder.start(1000)
    }
  }

  const onRecordClick = async () => {
    if (isTransmitting && stream.current) {
      stream.current.getTracks().forEach(track => track.stop())
    } else {
      const constraints = {
        audio: { deviceId: audioDevice?.deviceId },
        video: {
          deviceId: videoDevice?.deviceId,
          width: { min: 1024, ideal: 1280, max: 1920 },
          height: { min: 576, ideal: 720, max: 1080 }
        }
      }
      if (!socket.current?.isConnected()) {
        socket.current?.connect()
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

    setTransmitting(!isTransmitting)
  }

  const loadDevices = async () => {
    try {
      setDevices(await navigator.mediaDevices.enumerateDevices())
    } catch (error) {
      console.error(error)

      toast({
        title: "Error ocurred opening Multimedia devices.",
        description: "please hold on",
        status: "error",
        duration: 9000,
        isClosable: true,
      })
    }
  }

  const getDevice = (deviceId: MediaDeviceInfo['deviceId'], devices: MediaDeviceInfo[]) => devices.find(device => device.deviceId === deviceId)
  const getDefaultDevice = (devices: MediaDeviceInfo[]): MediaDeviceInfo | undefined => getDevice('default', devices)

  const handleFileChange = ({ target: { files } }: React.ChangeEvent<HTMLInputElement>) => {
    if (!files) return
    upload(files[0])
  }

  const token = getToken()

  React.useEffect(() => {
    if (token) {
      socket.current = new Socket(`${env?.WS_API_HOST}/socket`, { params: { token } })
      socket.current.onError(() => console.log("there was an error with the connection!"))
      socket.current.onClose(() => console.log("the connection dropped"))
    }
    loadDevices()
    return socket.current?.disconnect()
  }, [token])

  React.useEffect(() => {
    if (devices && devices.length > 0) {
      setAudioDevices(devices.filter(({ kind }: MediaDeviceInfo) => kind === "audioinput") as unknown as InputDeviceInfo[])
      setVideoDevices(devices.filter(({ kind }: MediaDeviceInfo) => kind === "videoinput"))
    }
  }, [devices])

  React.useEffect(() => {
    if (!channel.current && socket.current) {
      channel.current = socket.current.channel(`transmit:${uuid}`)
      channel.current.onError(() => console.error("there was an error!"))
      channel.current.onClose(() => {
        setTransmitting(false)
        console.warn("the channel has gone away gracefully")
      })

      channel.current
        .join()
        .receive("ok", (response) => console.info(response))
        .receive("error", (response) => console.error(response))
    }
  }, [socket, uuid])


  const defaultAudioDevice = getDefaultDevice(audioDevices)
  const defaultVideoDevice = getDefaultDevice(videoDevices)

  return <Box maxW={{ sm: 'lg' }} mx={{ sm: 'auto' }} mt="8" w={{ sm: 'full' }}>
    <Box
      py="8"
      px={{ base: '4', md: '10' }}
      shadow="base"
      rounded={{ sm: 'lg' }}
    >
      {data?.transmission?.type === 'live' ? <VStack
        divider={<StackDivider borderColor="gray.200" />}
        spacing={4}
        align="stretch">
        <Box>
          <Text fontSize="2xl">
            Transmission URL
          </Text>
          <Text fontSize="sm">
            For streaming using programs such as Open Broad Caster
          </Text>
          <Code children={`${env?.RTMP_HOST}/live/${data?.transmission.uuid}`} />
        </Box>
        <Box>
          <Container centerContent>
            <Player uuid={uuid} forwardRef={videoRef} />
            <Button onClick={onRecordClick} colorScheme={isTransmitting ? "red" : "blue"} leftIcon={isTransmitting ? <FaStop /> : <FaPlay />}>
              {isTransmitting ? "Stop" : "Record"}
            </Button>
          </Container>
        </Box>
        <Box>
          <Text fontSize="2xl" mb="4">
            Media Devices
          </Text>
          <Text fontSize="sm" mb="4">
            Select an audio and video devices to start streaming
          </Text>
          <HStack spacing={8}
            divider={<StackDivider borderColor="gray.200" />}>
            <Select onChange={event => setAudioDevice(getDevice(event.target.value, audioDevices))}
              defaultValue={defaultAudioDevice?.deviceId} placeholder={`Available ${audioDevices.length}`} icon={<FaCamera />}>
              {audioDevices?.map((device, key) => <option key={key} value={device.deviceId}>{device.label}</option>)}
            </Select>
            <Select onChange={event => setVideoDevice(getDevice(event.target.value, videoDevices))}
              defaultValue={defaultVideoDevice?.deviceId} placeholder={`Available ${videoDevices.length}`} icon={<FaMicrophone />}>
              {videoDevices?.map((device, key) => <option key={key} value={device.deviceId}>{device.label}</option>)}
            </Select>
          </HStack>
        </Box>
      </VStack> : <VStack
        divider={<StackDivider borderColor="gray.200" />}
        spacing={4}
        align="stretch">
        <FormControl>
          <FormLabel>
            Upload
          </FormLabel>
          <Input onChange={handleFileChange} type="file" />
          <FormHelperText>
            Drag and Drop or select a file to start transmitting, it has to be mp4
          </FormHelperText>
        </FormControl>
        {isUploading && <Progress value={progress} />}
      </VStack>}
    </Box>
  </Box>
}

export default Edit