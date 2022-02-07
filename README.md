# HolySound - Pi-hole and balenaSound mashup

Mix [Pi-hole](https://pi-hole.net/) and [balenaSound](https://sound.balenalabs.io/) to single [balenaCloud](https://www.balena.io/cloud/) application, following the [Two projects, one device: turn your Raspberry Pi into a multitool!](https://www.balena.io/blog/two-projects-one-device-turn-your-raspberry-pi-into-a-multitool/) blog post.

## Features

* Custom hostname

* Static IP and CloudFlare DNS

* Unbound (recursive DNS) and fbcp (display driver) **removed** from Pi-hole

## Setup application in balenaCloud

* Create new application **holy-sound** in [balenaCloud](https://www.balena.io/cloud/)

* Set the following _Fleet (application) Variables_

    | Name                  | Value          | Note 
    |-----------------------|----------------|------
    | PIHOLE_DNS_           | 208.67.222.222;208.67.220.220 | Upstream DNS (where a non-blocked DNS queries will be forwarded)
    | SOUND_MODE            | STANDALONE     | Disable [Multi-room](https://sound.balenalabs.io/docs/usage#modes-of-operation) (only single device playing)
    | SOUND_SPOTIFY_BITRATE | 320            | Spotify playback bitrate (default is 160)
    | SOUND_SUPERVISOR_PORT | 8081           | Port for API and UI of Sound supervisor (default is 80 what collide with Pi-hole UI)
    | TZ                    | Continent/City | Timezone

* Add device

* Set the following _Device Variables_

    | Name                       | Value        | Note 
    |----------------------------|--------------|------
    | BLUETOOTH_DEVICE_NAME      | balenaSound  | How the device will be shown in Bluetooth connections
    | ServerIP                   | 192.168.1.2  | Device IP address
    | SOUND_DEVICE_NAME          | balenaPlayer | Spotify Connect and AirPlay name
    | SOUND_SPOTIFY_ENABLE_CACHE | true         | Enable caching (only for devices with enough disk space)
    | WEBPASSWORD                | secret       | Password to access Pi-hole Web Interface at [http://\<ServerIP\>/admin/](http://ServerIP/admin/)

* Set the following _Device Configuration_ (in _CUSTOM CONFIGURATION VARIABLES_ section)

    | Name                         | Value             | Note 
    |------------------------------|-------------------|------
    | BALENA_HOST_CONFIG_dtoverlay | hifiberry-dacplus | Value from supported [DAC boards](https://sound.balenalabs.io/docs/audio-interfaces#dac-boards)

* Download and flash balenaOS image

## Deploy

* Clone this repo

* Pull submodules

        git submodule update --init

* Mount SD Card

* Patch image settings with

        ./patch-balena-settings.sh --hostname <HOSTNAME> --ip <ServerIP>/<RANGE> --gw <IP> <MOUNT_POINT>
  
  E.g. `./patch-balena-settings.sh --hostname spongebob --ip 192.168.1.2/24 --gw 192.168.1.1 /mnt/balenaOS`

* Unmount SD Card

* Power on RPi and wait until device appears in balenaCloud

* Build and push **holy-sound** application to balenaCloud

        balena push holy-sound --multi-dockerignore

## Update

* Update submodules

        git submodule update --remote --merge

* Update `docker-compose.yml` with eventual changes from [balena-pihole/docker-compose.yml](https://github.com/klutchell/balena-pihole/blob/main/docker-compose.yml) and [balena-sound/docker-compose.yml](https://github.com/balenalabs/balena-sound/blob/master/docker-compose.yml)

* Build and push new **holy-sound** application release to balenaCloud

        balena push holy-sound --multi-dockerignore

## Links

* Pi-hole customization values in [Docker image details](https://hub.docker.com/r/pihole/pihole/)

* balenaSound customization values in [documentation](https://sound.balenalabs.io/docs/customization)
