#!/bin/bash

V2RAY_CONFIG="/etc/v2ray/client.json"
ADDRESS=`cat $V2RAY_CONFIG | jq -r ' ."outbounds"[0]."settings"."vnext"[0]."address" '`
PORT=`cat $V2RAY_CONFIG | jq -r ' ."outbounds"[0]."settings"."vnext"[0]."port" '`
UUID=`cat $V2RAY_CONFIG | jq -r ' ."outbounds"[0]."settings"."vnext"[0]."users"[0]."id" '`
ALTERID=`cat $V2RAY_CONFIG | jq -r ' ."outbounds"[0]."settings"."vnext"[0]."users"[0]."alterId" '`
WSPATH=`cat $V2RAY_CONFIG | jq -r ' ."outbounds"[0]."streamSettings"."wsSettings"."path" '`
if [ "$WSPATH" = "null" ]; then WSPATH=""; fi
SNI=`cat /etc/v2ray/client.json|jq -r ' ."outbounds"[0]."streamSettings"."tlsSettings"."serverName" '`
if [ "$SNI" = "null" ]; then SNI=""; fi
STREAM_SECURITY=`cat /etc/v2ray/client.json|jq -r ' ."outbounds"[0]."streamSettings"."security" '`
if [ "$STREAM_SECURITY" = "null" ]; then STREAM_SECURITY=""; fi

V2RAYINFO="{}"
V2RAYINFO=$( echo $V2RAYINFO| jq ". += {\"ps\":\"SERVER-V2RAY\"}" )
V2RAYINFO=$( echo $V2RAYINFO| jq ". += {\"type\":\"none\"}" )
V2RAYINFO=$( echo $V2RAYINFO| jq ". += {\"v\":\"2\"}" )
V2RAYINFO=$( echo $V2RAYINFO| jq ". += {\"add\":\"$ADDRESS\"}" )
V2RAYINFO=$( echo $V2RAYINFO| jq ". += {\"aid\":\"$ALTERID\"}" )
V2RAYINFO=$( echo $V2RAYINFO| jq ". += {\"id\":\"$UUID\"}" )
V2RAYINFO=$( echo $V2RAYINFO| jq ". += {\"port\":\"$PORT\"}" )
V2RAYINFO=$( echo $V2RAYINFO| jq ". += {\"host\":\"$SNI\"}" )

if [ -z "$WSPATH" ]; then
    V2RAYINFO=$( echo $V2RAYINFO| jq ". += {\"net\":\"tcp\"}" )
else
    V2RAYINFO=$( echo $V2RAYINFO| jq ". += {\"net\":\"ws\"}" )
    V2RAYINFO=$( echo $V2RAYINFO| jq ". += {\"path\":\"$WSPATH\"}" )
fi

if [ -z "$STREAM_SECURITY" ] ; then
        V2RAYINFO=$( echo $V2RAYINFO| jq ". += {\"tls\":\"none\"}" )
else
        V2RAYINFO=$( echo $V2RAYINFO| jq ". += {\"tls\":\"$STREAM_SECURITY\"}" )
fi

V2RAYINFO=`echo $V2RAYINFO|jq -c|base64|tr -d '\n'`

V2IP=`dig +short $ADDRESS|head -n1`
if [ -z "$V2IP" ]; then
    V2IP=$ADDRESS
fi

echo "VPS-Server: $V2IP"
echo "V2Ray-vmess-URI: vmess://$V2RAYINFO"
qrcode-terminal "vmess://$V2RAYINFO"
