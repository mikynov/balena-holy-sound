#!/usr/bin/env bash

readonly TRACE=${TRACE:-}
[[ "${TRACE}" ]] && set -o xtrace
set -o errexit
set -o errtrace
set -o nounset
set -o pipefail
set -o noclobber
IFS=$'\n\t'

# shellcheck disable=SC2034
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_help() {
    cat <<EOF
NAME
    ${0} - Update the balenaOS boot settings

SYNOPSIS
    ${0} [ARGS...] [MOUNTPOINT]

DESCRIPTION
     Set custom hostname and network profile settings
     on boot partition of balenaOS image.

     --hostname     Device hostname
     --ip           Device IP address AND range
     --gw           Default gateway IP address

EXAMPLES
    Set the hostname 'spongeboob' and IP address with 255.255.0.0 netmask
    to balenaOS boot mounted on /mnt/balenaOS:

        ${0} --hostname spongebob --ip 192.168.1.2/16 --gw 192.168.1.1 /mnt/balenaOS

EOF
}

_parse_args() {
    declare -a -g _POSITIONAL_PARAMS

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|-\?|--help)
                _help
                exit 1
                ;;
            --hostname)
                if [[ -z "${2-}" || "${2:0:1}" == "-" ]]; then
                    echo "ERROR: Undefined value for ${1}" >&2
                    exit 1
                else
                    readonly HOSTNAME="${2}"
                    shift 2
                fi
                ;;
            --ip)
                if [[ -z "${2-}" || "${2:0:1}" == "-" ]]; then
                    echo "ERROR: Undefined value for ${1}" >&2
                    exit 1
                else
                    readonly IP="${2}"
                    shift 2
                fi
                ;;
            --gw)
                if [[ -z "${2-}" || "${2:0:1}" == "-" ]]; then
                    echo "ERROR: Undefined value for ${1}" >&2
                    exit 1
                else
                    readonly GW="${2}"
                    shift 2
                fi
                ;;
            --)
                shift
                break
                ;;        
            -*)
                echo "ERROR: Unknown argument ${1}" >&2
                exit 1
                ;;
            *)
                _POSITIONAL_PARAMS+=("${1}")
                shift
                ;;
        esac
    done
    eval set -- "${_POSITIONAL_PARAMS[@]}"
}

_main() {
    ! hash jq 2>/dev/null \
        && (echo "ERROR: Requires jq (https://stedolan.github.io/jq/)"; exit 3)

    _parse_args "${@}"
    eval set -- "${_POSITIONAL_PARAMS[@]}"

    [[ ${#} -lt 1 ]] \
        && (_help; exit 2)
    [[ -z ${HOSTNAME-} || -z ${IP-} || -z ${GW-} || -z ${1-} ]] \
        && (_help; exit 2)
    [[ ! -f ${1}/config.json || ! -d ${1}/system-connections ]] \
        && (echo "${1} doesn't seem to be mounted balenaOS partition" && exit 3)
    [[ ! ${IP} == *"/"* ]] \
        && (echo "IP address parameter MUST include range (e.g. ${IP}/16)"; exit 2)

    echo "Patching ${1}/config.json with '\"hostname\": \"${HOSTNAME}\"'..."
    config_temp=$(mktemp /tmp/balena-config-XXXXXX)
    jq --arg hostname "$HOSTNAME" -s '.[0] * {"hostname": $hostname}' "${1}/config.json" >> "${config_temp}" \
        && mv "${config_temp}" "${1}/config.json"

    echo "Writing ${1}/system-connections/eth0-static with \"address1=${IP},${GW}\"..."
    rm -f "${1}/system-connections/eth0-static"
    cat > "${1}/system-connections/eth0-static" <<EOF
[connection]
id=eth0-static
type=ethernet
interface-name=eth0
permissions=
secondaries=

[ethernet]
mac-address-blacklist=

[ipv4]
address1=${IP},${GW}
dns=1.0.0.1;1.1.1.1;
dns-search=
method=manual

[ipv6]
addr-gen-mode=stable-privacy
dns-search=
method=auto
EOF
}

[[ "${BASH_VERSINFO[0]}" -lt 4 ]] && echo "Requires Bash >= 4" && exit 44
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && _main "${@}"
