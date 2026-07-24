#!/bin/bash
#
# Send a test FCM message to a topic for one festival app.
# Each flavor uses a SEPARATE Firebase project — the server key must match the target app.
#
# Usage:
#   ./scripts/send_fcm_topic.sh -mdf "Hello MDF"
#   ./scripts/send_fcm_topic.sh -mmf "Hello MMF"
#   ./scripts/send_fcm_topic.sh -70k "Hello 70K"
#   ./scripts/send_fcm_topic.sh -mdf -t Testing20260618 "Test channel"
#
# Requires in andriod/.env (see .env.example):
#   FIREBASE_SERVER_KEY_MDF=...   (Firebase Console → mdf-bands → Project settings → Cloud Messaging)
#   FIREBASE_SERVER_KEY_MMF=...
#   FIREBASE_SERVER_KEY_70K=...
#
# App subscribes to topics: global (main), Testing20260618 (test). Names are the same across
# festivals but each project has its own topic namespace.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

DO_70K=false
DO_MDF=false
DO_MMF=false
TOPIC="global"

usage() {
    echo "Send FCM topic push to 70K, MDF, or MMF (separate Firebase projects)."
    echo ""
    echo "  -70k -mdf -mmf     Target app (required, one only)"
    echo "  -t TOPIC           Topic name (default: global)"
    echo "  -h                 Help"
    echo ""
    echo "Firebase projects:"
    echo "  70K → spherical-plane-122200"
    echo "  MDF → mdf-bands"
    echo "  MMF → mmf-bands"
    echo ""
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ANDROID_DIR"

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        -70k) DO_70K=true ;;
        -mdf) DO_MDF=true ;;
        -mmf) DO_MMF=true ;;
        -t)
            shift
            TOPIC="${1:?Missing topic after -t}"
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            exit 1
            ;;
        *)
            break
            ;;
    esac
    shift
done

MESSAGE="${*:-Test push from send_fcm_topic.sh}"

SELECTED=0
if [ "$DO_70K" = true ]; then SELECTED=$((SELECTED + 1)); FESTIVAL="70K"; KEY_VAR="FIREBASE_SERVER_KEY_70K"; PROJECT="spherical-plane-122200"; fi
if [ "$DO_MDF" = true ]; then SELECTED=$((SELECTED + 1)); FESTIVAL="MDF"; KEY_VAR="FIREBASE_SERVER_KEY_MDF"; PROJECT="mdf-bands"; fi
if [ "$DO_MMF" = true ]; then SELECTED=$((SELECTED + 1)); FESTIVAL="MMF"; KEY_VAR="FIREBASE_SERVER_KEY_MMF"; PROJECT="mmf-bands"; fi

if [ "$SELECTED" -ne 1 ]; then
    echo -e "${RED}Error: specify exactly one of -70k, -mdf, -mmf${NC}"
    usage
    exit 1
fi

if [ ! -f ".env" ]; then
    echo -e "${RED}Error: .env not found in $ANDROID_DIR${NC}"
    exit 1
fi

set -a
# shellcheck source=/dev/null
source .env
set +a

SERVER_KEY="${!KEY_VAR}"
if [ -z "$SERVER_KEY" ]; then
    echo -e "${RED}Error: $KEY_VAR not set in .env${NC}"
    echo "Get the legacy server key from Firebase Console → $PROJECT → Project settings → Cloud Messaging"
    exit 1
fi

PAYLOAD=$(python3 -c "
import json, sys
print(json.dumps({
    'to': '/topics/$TOPIC',
    'notification': {
        'title': '$FESTIVAL Bands test',
        'body': sys.argv[1],
    },
    'data': {
        'message': sys.argv[1],
    },
}))
" "$MESSAGE")

echo -e "${BLUE}Sending to $FESTIVAL (Firebase project $PROJECT) topic /topics/$TOPIC${NC}"
echo "Message: $MESSAGE"
echo ""

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "https://fcm.googleapis.com/fcm/send" \
    -H "Authorization: key=$SERVER_KEY" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "$BODY"
echo ""

if [ "$HTTP_CODE" = "200" ] && echo "$BODY" | grep -q '"success":1'; then
    echo -e "${GREEN}✓ FCM accepted the message${NC}"
    exit 0
fi

echo -e "${RED}✗ FCM send failed (HTTP $HTTP_CODE)${NC}"
echo "If MDF fails but MMF works, you are almost certainly using the wrong project's server key."
exit 1
