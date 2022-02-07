#!/usr/bin/env bash

readonly TRACE="${TRACE:-}"
[[ -n "${TRACE}" ]] && set -o xtrace
set -o errexit
set -o errtrace
set -o nounset
set -o pipefail
set -o noclobber
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2034
readonly SCRIPT_DIR

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
     --ip           Device IP address AND range (i.e. netmask)
     --gw           Default gateway IP address
     --ssh          Public SSH key for root access with standalone SSH client
                    (https://www.balena.io/docs/learn/manage/ssh-access/#using-a-standalone-ssh-client)

EXAMPLES
    Set the hostname 'spongebob' and IP address with 255.255.0.0 netmask
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
                    readonly SET_HOSTNAME="${2}"
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
            --ssh)
                if [[ -z "${2-}" || "${2:0:1}" == "-" ]]; then
                    echo "ERROR: Undefined value for ${1}" >&2
                    exit 1
                else
                    readonly SSH_KEY="${2}"
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
    # shellcheck disable=SC2294
    eval set -- "${_POSITIONAL_PARAMS[@]}"
}

_main() {
    ! hash jq 2>/dev/null \
        && (echo "ERROR: Requires jq (https://stedolan.github.io/jq/)"; exit 3)

    _parse_args "${@}"
    # shellcheck disable=SC2294
    eval set -- "${_POSITIONAL_PARAMS[@]}"

    [[ ${#} -lt 1 ]] \
        && (_help; exit 2)
    [[ -z ${SET_HOSTNAME-} || -z ${IP-} || -z ${GW-} || -z ${1-} ]] \
        && (_help; exit 2)
    [[ ! -f ${1}/config.json || ! -d ${1}/system-connections ]] \
        && (echo "${1} doesn't seem to be mounted balenaOS partition" && exit 3)
    [[ ! ${IP} == *"/"* ]] \
        && (echo "IP address parameter MUST include range (e.g. ${IP}/16)"; exit 2)
    [[ -n ${SSH_KEY:-} && ! ${SSH_KEY} == "ssh-rsa "* ]] \
        && (echo "Provided SSH key doesn't looks as public SSH key"; exit 2)

    echo "Patching ${1}/config.json with '\"hostname\": \"${SET_HOSTNAME}\"'..."
    config_temp=$(mktemp /tmp/balena-config-XXXXXX)

    jq_hostname() {
        jq --arg hostname "$SET_HOSTNAME" -s '.[0] * {"hostname": $hostname}'
    }
    jq_dnsservers() {
        # Do not add 8.8.8.8 to the list of DNS servers configured in the NetworkManager
        # https://www.balena.io/docs/reference/OS/configuration/#dnsservers
        jq -s '.[0] * {"dnsServers": ""}'
    }
    jq_ssh() {
        if [[ -n ${SSH_KEY:-} ]]; then
            jq --arg ssh_key "$SSH_KEY" -s '.[0] * {"os": {"sshKeys": [$ssh_key]}}'
        else
            cat
        fi
    }

    jq_hostname < "${1}/config.json" | jq_dnsservers | jq_ssh >> "${config_temp}" \
        && mv "${config_temp}" "${1}/config.json"

    echo "Patching docker-compose.yml..."
    sed --in-place "s/SET_HOSTNAME:.*$/SET_HOSTNAME: ${SET_HOSTNAME}/" docker-compose.yml

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
