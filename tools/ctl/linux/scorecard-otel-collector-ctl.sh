#!/bin/sh

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License").
# You may not use this file except in compliance with the License.
# A copy of the License is located at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# or in the "license" file accompanying this file. This file is distributed
# on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
# express or implied. See the License for the specific language governing
# permissions and limitations under the License.

set -e
set -u

readonly AGENTDIR="/opt/scorecard/scorecard-otel-collector"
readonly CMDDIR="${AGENTDIR}/bin"
readonly CONFDIR="${AGENTDIR}/etc"
readonly ENV_FILE="${CONFDIR}/.env"
readonly DFT_CONFDIR="${AGENTDIR}/var"
readonly VERSION_FILE="${CMDDIR}/VERSION"

SYSTEMD='false'

UsageString="

  usage: scorecard-otel-collector-ctl -a stop|start|status| [-c <config-uri>]

  e.g.
  1. start collector on onPermise host with a custom .yaml config file:
  sudo scorecard-otel-collector-ctl -c /tmp/config.yaml -a start
  2. stop the running collector
  sudo scorecard-otel-collector-ctl -a stop
  3. query agent status:
  sudo scorecard-otel-collector-ctl -a status

  -a: action
  stop:                                   stop the agent process.
  start:                                  start the agent process.
  status:                                 get the status of the agent process.

  -c: configuration
  <config-uri>:                           - file path on the host. E.g.: /tmp/config.yaml or file:/tmp/config.yaml
                                          - http uri. E.g.: http://example.com/config
                                          - https uri. E.g.: https://example.com/config
                                          - s3 uri. E.g.: s3://bucket/config

  "

soc_config_remote_uri() {
    config="${1:-}"

    sed -i '/^config=.*$/d' $ENV_FILE
    echo "config=\"--config '${config}'\"" >> $ENV_FILE
}


soc_config_local_uri() {
    config="${1:-}"

    # Strip the file scheme in case it is present
    config="${config#file:}"

    sed -i '/^config=.*$/d' $ENV_FILE
    echo "config=\"--config /opt/scorecard/scorecard-otel-collector/etc/config.yaml\"" >> $ENV_FILE


    if [ -n "$config" ] && [ -f "$config" ]; then
        # do not copy if the default congif directory is provided for the -f flag.
        # copying a file to the same location produces an error. 
        if [ ! "$config" = "$CONFDIR/config.yaml" ]; then
            cp "$config" $CONFDIR/config.yaml
        fi
    else
        echo "File $config does not exist"
        exit 1
    fi
}

# Used in case the collector starts for the first time without a configuration parameter
# Safe to run as this will not overwrite a file if one exists in default location already.
soc_ensure_default_config() {
    if [ ! -f $CONFDIR/config.yaml ]; then
        cp -p $DFT_CONFDIR/.config.yaml $CONFDIR/config.yaml
    fi
}

is_remote_uri() {
    config="${1:-}"

    if echo "$config" | grep -E -q "^[a-zA-Z0-9]+://" && \
       ! echo "$config" | grep -E -q "^file:"; then
        return 0;
    fi
    return 1
}

soc_start() {
    config="${1:-}"

    # The previous configuration should be used if no configuration parameter is passed
    soc_ensure_default_config
    if [ -n "$config" ]; then
        if is_remote_uri "$config"; then
            soc_config_remote_uri "$config"
        else
            soc_config_local_uri "$config"
        fi
    fi

    if [ "${SYSTEMD}" = 'true' ]; then
        systemctl daemon-reload
        systemctl enable scorecard-otel-collector.service
        service scorecard-otel-collector restart
    else
        start scorecard-otel-collector
        sleep 1
    fi
}

soc_stop() {
    if [ "$(soc_runstatus)" = 'stopped' ]; then
        return 0
    fi

    if [ "${SYSTEMD}" = 'true' ]; then
        service scorecard-otel-collector stop
    else
        stop scorecard-otel-collector || true
    fi
}

soc_preun() {
    soc_stop
    if [ "${SYSTEMD}" = 'true' ]; then
        systemctl disable scorecard-otel-collector.service
        systemctl daemon-reload
        systemctl reset-failed
    fi
}

soc_status() {
    pid=''
    if [ "${SYSTEMD}" = 'true' ]; then
        pid="$(systemctl show -p MainPID scorecard-otel-collector.service | sed s/MainPID=//)"
    else
        pid="$(initctl status scorecard-otel-collector | sed -n s/^.*process\ //p)"
    fi

    starttime_fmt=''
    if [ -n "${pid}" ] && [ "${pid}" -ne "0" ]; then
        starttime="$(TZ=UTC ps -o lstart= "${pid}")"
        starttime_fmt="$(TZ=UTC date -Isec -d "${starttime}")"
    fi

    version="$(cat ${VERSION_FILE})"

    echo "{"
    echo "  \"status\": \"$(soc_runstatus)\","
    echo "  \"starttime\": \"${starttime_fmt}\","
    echo "  \"version\": \"${version}\""
    echo "}"
}

soc_runstatus() {
    running=false
    if [ "${SYSTEMD}" = 'true' ]; then
        set +e
        if systemctl is-active scorecard-otel-collector.service 1>/dev/null; then
            running='true'
        fi
        set -e
    else
        if [ "$(initctl status scorecard-otel-collector | grep -c running)" = 1 ]; then
            running='true'
        fi
    fi

    if [ "${running}" = 'true' ]; then
        echo "running"
    else
        echo "stopped"
    fi
}

main() {
    action=''
    mode='ec2'
    config_location=''

    # detect which init system is in use
    if [ "$(/sbin/init --version 2>/dev/null | grep -c upstart)" = 1 ]; then
        SYSTEMD='false'
    elif [ "$(systemctl | grep -c '\-\.mount')" = 1 ]; then
        SYSTEMD='true'
    elif [ -f /etc/init.d/cron ] && [ ! -h /etc/init.d/cron ]; then
        echo "sysv-init is not supported" >&2
        exit 1
    else
        echo "unknown init system" >&2
        exit 1
    fi

    OPTIND=1
    while getopts ":ha:c:m:" opt; do
        case "${opt}" in
        h)
            echo "${UsageString}"
            exit 0
            ;;
        a) action="${OPTARG}" ;;
        c) config_location="${OPTARG}" ;;
        m) mode="${OPTARG}" ;;
        \?)
            echo "Invalid option: -${OPTARG} ${UsageString}" >&2
            ;;
        :)
            echo "Option -${OPTARG} requires an argument ${UsageString}" >&2
            exit 1
            ;;
        esac
    done
    shift "$(( OPTIND - 1))"

    case "${mode}" in
    ec2) ;;

    onPremise) ;;

    auto) ;;

    *)
        echo "Invalid mode: ${mode} ${UsageString}" >&2
        exit 1
        ;;
    esac

    case "${action}" in
    stop) soc_stop ;;
    start) soc_start "${config_location}" ;;
    status) soc_status ;;
    # helper for rpm+deb uninstallation hooks, not expected to be called manually
    preun) soc_preun ;;
    *)
        echo "Invalid action: ${action} ${UsageString}" >&2
        exit 1
        ;;
    esac
}

main "$@"
