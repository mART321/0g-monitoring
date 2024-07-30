#!/bin/bash

if ! command -v jq &> /dev/null || ! command -v curl &> /dev/null
then
    echo "jq and curl are required but not installed. Please install them and try again."
    exit 1
fi

TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
STORAGE_RPC=""
#if you do not have a validator node, then leave the field empty; 
#              |
#              |    
#              V there ;)
VALIDATOR_RPC=""
NODE_NAME="0G_NODE"
PARENT_RPC="https://og-testnet-rpc.itrocket.net"
SLEEP_INTERVAL=15 
MAX_ATTEMPTS=10   

send_telegram() {
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" -d chat_id=$TELEGRAM_CHAT_ID -d text="$1"
}

time_to_next_interval() {
    local current_minute=$(date +%M)
    local next_interval=$(( (current_minute / SLEEP_INTERVAL + 1) * SLEEP_INTERVAL ))
    local sleep_time=$(( next_interval * 60 - $(date +%s) % 3600 ))
    echo $sleep_time
}

check_block_height_and_peers() {
    local RPC=$1
    echo "0G_NODE: CHECKING RPC BLOCK HEIGHT AND CONNECTED PEERS FOR $RPC..."

    RESPONSE=$(curl -s --max-time 3 -X POST $RPC -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"zgs_getStatus","params":[],"id":1}')
    HEIGHT=$(echo $RESPONSE | jq -r '.result.logSyncHeight' 2>/dev/null)
    PEERS=$(echo $RESPONSE | jq -r '.result.connectedPeers' 2>/dev/null)

    echo "CURRENT RPC BLOCK HEIGHT: $HEIGHT"
    echo "CONNECTED PEERS: $PEERS"

    if [[ $PEERS -eq 0 ]]; then
        send_telegram "0G_NODE: RPC $RPC HAS 0 CONNECTED PEERS."
        echo "ALERT: RPC $RPC HAS 0 CONNECTED PEERS."
    fi

    ATTEMPTS=0
    while [[ $ATTEMPTS -lt $MAX_ATTEMPTS ]]; do
        PARENT_HEIGHT=$(curl -s --max-time 3 "$PARENT_RPC/block" | jq -r '.result.block.header.height' 2>/dev/null)
        if [[ $PARENT_HEIGHT =~ ^[0-9]+$ ]]; then
            break
        fi
        ATTEMPTS=$((ATTEMPTS + 1))
        echo "ATTEMPT $ATTEMPTS/$MAX_ATTEMPTS: PARENT RPC $PARENT_RPC IS DOWN OR SENT AN INVALID RESPONSE. RETRYING IN 5 SECONDS..."
        sleep 5
    done

    if [[ $ATTEMPTS -eq $MAX_ATTEMPTS ]]; then
        send_telegram "0G_NODE: PARENT RPC $PARENT_RPC IS DOWN OR SENT AN INVALID RESPONSE AFTER $MAX_ATTEMPTS ATTEMPTS."
        echo "ERROR: 0G_NODE PARENT RPC $PARENT_RPC IS DOWN OR SENT АН INVALID RESPONSE AFTER $MAX_ATTEMPTS ATTEMPTS."
        return 1
    fi

    echo "PARENT RPC BLOCK HEIGHT: $PARENT_HEIGHT"

    if [[ $HEIGHT -ne 0 ]] && [[ $PARENT_HEIGHT -ne 0 ]]; then
        DIFF=$((PARENT_HEIGHT - HEIGHT))
        if [[ $DIFF -gt 25 ]]; then
            send_telegram "0G_NODE: RPC BLOCK HEIGHT DIFFERENCE $DIFF. RPC: $HEIGHT, PARENT RPC: $PARENT_HEIGHT."
            echo "ALERT: BLOCK HEIGHT DIFFERENCE IS $DIFF. RPC: $HEIGHT, PARENT RPC: $PARENT_HEIGHT."
        else
            echo "BLOCK HEIGHT WITHIN ACCEPTABLE RANGE."
        fi
    fi

    return 0
}

check_block_height() {
    local RPC=$1
    echo "0G_NODE: CHECKING RPC BLOCK HEIGHT FOR $RPC..."

    RESPONSE=$(curl -s --max-time 3 -X POST $RPC -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"zgs_getStatus","params":[],"id":1}')
    HEIGHT=$(echo $RESPONSE | jq -r '.result.logSyncHeight' 2>/dev/null)

    echo "CURRENT RPC BLOCK HEIGHT: $HEIGHT"

    ATTEMPTS=0
    while [[ $ATTEMPTS -lt $MAX_ATTEMPTS ]]; do
        PARENT_HEIGHT=$(curl -s --max-time 3 "$PARENT_RPC/block" | jq -r '.result.block.header.height' 2>/dev/null)
        if [[ $PARENT_HEIGHT =~ ^[0-9]+$ ]]; then
            break
        fi
        ATTEMPTS=$((ATTEMPTS + 1))
        echo "ATTEMPT $ATTEMPTS/$MAX_ATTEMPTS: PARENT RPC $PARENT_RPC IS DOWN OR SENT АН INVALID RESPONSE. RETRYING IN 5 SECONDS..."
        sleep 5
    done

    if [[ $ATTEMPTS -eq $MAX_ATTEMPTS ]]; then
        send_telegram "0G_NODE: PARENT RPC $PARENT_RPC IS DOWN OR SENT АН INVALID RESPONSE AFTER $MAX_ATTEMPTS ATTEMPTS."
        echo "ERROR: 0G_NODE PARENT RPC $PARENT_RPC IS DOWN OR SENT АН INVALID RESPONSE AFTER $MAX_ATTEMPTS ATTEMPTS."
        return 1
    fi

    echo "PARENT RPC BLOCK HEIGHT: $PARENT_HEIGHT"

    if [[ $HEIGHT -ne 0 ]] && [[ $PARENT_HEIGHT -ne 0 ]]; then
        DIFF=$((PARENT_HEIGHT - HEIGHT))
        if [[ $DIFF -gt 25 ]]; then
            send_telegram "0G_NODE: RPC BLOCK HEIGHT DIFFERENCE $DIFF. RPC: $HEIGHT, PARENT RPC: $PARENT_HEIGHT."
            echo "ALERT: BLOCK HEIGHT DIFFERENCE IS $DIFF. RPC: $HEIGHT, PARENT RPC: $PARENT_HEIGHT."
        else
            echo "BLOCK HEIGHT WITHIN ACCEPTABLE RANGE."
        fi
    fi

    return 0
}

while true; do
    check_block_height_and_peers "$STORAGE_RPC"

    if [[ -n "$VALIDATOR_RPC" ]]; then
        check_block_height "$VALIDATOR_RPC"
    fi

    SLEEP_TIME=$(time_to_next_interval)
    echo "0G_NODE: WAITING $SLEEP_TIME SECONDS BEFORE NEXT CHECK..."
    sleep $SLEEP_TIME
done
