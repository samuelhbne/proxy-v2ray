#!/bin/bash

usage() {
	echo "proxy-v2ray -h|--host <v2ray-host> -u|--uuid <vmess-uuid> [-p|--port <port-num>] [-l|--level <level>] [-a|--alterid <alterid>] [-s|--security <client-security>]"
	echo "    -h|--host <v2ray-host>            V2ray server host name or IP address"
	echo "    -u|--uuid <vmess-uuid>            Vmess UUID for initial V2ray connection"
	echo "    -p|--port <port-num>              [Optional] Port number for V2ray connection, default 10086"
	echo "    -l|--level <level>                [Optional] Level number for V2ray service access, default 0"
	echo "    -a|--alterid <alterid>            [Optional] AlterID number for V2ray service access, default 16"
	echo "    -s|--security <client-security>   [Optional] V2ray client security setting, default 'auto'"
	echo "    --wp <websocket-path>             [Optional] Connect via websocket with given websocket-path, e.g. '/wsocket'"
	echo "    --no-ssl                          [Optional] Disable ssl support when connect via websocket, only for testing"
}

TEMP=`getopt -o h:u:p:l:a:s: --long host:,uuid:,port:,level:,alterid:,security:,wp:,no-ssl -n "$0" -- $@`
if [ $? != 0 ] ; then usage; exit 1 ; fi

eval set -- "$TEMP"
while true ; do
	case "$1" in
		-h|--host)
			HOST="$2"
			shift 2
			;;
		-u|--uuid)
			UUID="$2"
			shift 2
			;;
		-p|--port)
			PORT="$2"
			shift 2
			;;
		-l|--level)
			LEVEL="$2"
			shift 2
			;;
		-a|--alterid)
			ALTERID="$2"
			shift 2
			;;
		-s|--security)
			SECURITY="$2"
			shift 2
			;;
		--wp)
			if [[ $2 =~ ^\/[A-Za-z0-9_-]{1,16}$ ]]; then
				WSPATH="$2"
				shift 2
			else
				echo "Websocket path must be 1-16 aplhabets, numbers, '-' or '_' started with '/'"
				exit 1
			fi
			;;
		--no-ssl)
			NOSSL="true"
			shift 1
			;;
		--)
			shift
			break
			;;
		*)
			usage;
			exit 1
			;;
	esac
done

if [ -z "${HOST}" ] || [ -z "${UUID}" ]; then
	usage
	exit 2
fi

if [ -z "${PORT}" ]; then
	PORT=10086
fi

if [ -z "${ALTERID}" ]; then
	ALTERID=16
fi

if [ -z "${LEVEL}" ]; then
	LEVEL=0
fi

if [ -z "${SECURITY}" ]; then
	SECURITY="auto"
fi

LSTNADDR="0.0.0.0"
SOCKSPORT=1080

cd /tmp
cp -a /usr/bin/v2ray/vpoint_socks_vmess.json vsv.json
jq "(.inbounds[] | select( .protocol == \"socks\") | .listen) |= \"${LSTNADDR}\"" vsv.json >vsv.json.1
jq "(.inbounds[] | select( .protocol == \"socks\") | .port) |= \"${SOCKSPORT}\"" vsv.json.1 >vsv.json.2
jq "(.inbounds[] | select( .protocol == \"socks\") | .settings.ip) |= \"0.0.0.0\"" vsv.json.2>vsv.json.3
jq "(.outbounds[] | select( .protocol == \"freedom\") | .protocol) |= \"vmess\"" vsv.json.3>vsv.json.4
jq ".outbounds[0].settings |= . + { \"vnext\": [{\"address\": \"${HOST}\", \"port\": ${PORT}, \"users\": [{\"id\": \"${UUID}\", \"alterId\": ${ALTERID}, \"security\": \"${SECURITY}\", \"level\": ${LEVEL}}]}] }" vsv.json.4>client.json

if [ -n "${WSPATH}" ]; then
	cat client.json \
		| jq "(.outbounds[] | select( .protocol == \"vmess\")) +=  {\"streamSettings\":{\"network\":\"ws\",\"wsSettings\":{\"path\":\"${WSPATH}\"}}}" - \
		>client-ws.json
	mv client-ws.json client.json
fi

if [ -n "${NOSSL}" ]; then
	cat client.json \
		| jq "((.outbounds[] | select( .protocol == \"vmess\")) | .streamSettings) += {\"security\":\"none\"}" - \
		>client-ws.json
else
	cat client.json \
		| jq "((.outbounds[] | select( .protocol == \"vmess\")) | .streamSettings) += {\"security\":\"tls\"}" - \
		>client-ws.json
fi
mv client-ws.json client.json

/usr/bin/nohup /usr/bin/v2ray/v2ray -config=/tmp/client.json &
/root/polipo/polipo -c /root/polipo/config
exec /usr/bin/dnscrypt-proxy -config /etc/dnscrypt-proxy/dnscrypt-proxy.toml
