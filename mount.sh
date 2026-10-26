#!/bin/bash

read -p "Enter SMB username: " SMB_USER
read -s -p "Enter SMB password: " SMB_PASS
echo ""

# ssh-add -D
# eval "$(ssh-agent -s)"
# ssh-add ~/.ssh/id_ed25519_from_server

cleanup() {
    echo "Cleaning up..."
    sudo umount -l /Drive 2>/dev/null
    if [ -n "$SSH_PID" ]; then
        kill $SSH_PID 2>/dev/null
    fi
    echo "Processes ended."
    exit 0
}

trap cleanup SIGINT SIGTERM

connect_tunnel() {

    NGROK_API_KEY=$(cat ~/ngrok_key.txt)

    echo "Fetching ngrok tunnel URL..."
    TUNNEL_URL=$(curl -s \
        --request GET \
        --url 'https://api.ngrok.com/tunnels' \
        --header "Authorization: Bearer $NGROK_API_KEY" \
        --header 'ngrok-version: 2' | \
        jq -r '.tunnels[] | select(.proto == "tcp") | .public_url')

    if [ -z "$TUNNEL_URL" ]; then
        echo "Error: No active TCP tunnel found for SSH."
        return 1
    fi

    HOST_PORT_STRING=${TUNNEL_URL/tcp:\/\//}
    PORT=$(echo $HOST_PORT_STRING | awk -F: '{print $NF}')
    SERVER_ADDRESS=$(echo $HOST_PORT_STRING | sed 's/:[^:]*$//')

    PRE_PID=$(lsof -t -i :1390 | tail -1)
    if [ -n "$PRE_PID" ]; then
        kill $PRE_PID 2>/dev/null
    fi

    echo "Connecting to SSH at $TUNNEL_URL"
    
    ssh -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -f -N -L 1390:192.168.1.45:445 -p $PORT $USER@$SERVER_ADDRESS
    SSH_PID=$(lsof -t -i :1390 | tail -1)

    if [ -z "$SSH_PID" ]; then
        echo "Failed to start SSH tunnel."
        return 1
    fi

    sleep 2

    sudo umount -l /Drive 2>/dev/null
    sudo mount -t cifs //127.0.0.1/sharedrive /Drive -o username=$SMB_USER,password=$SMB_PASS,port=1390

    if [ $? -ne 0 ]; then
        echo "Mount failed."
        kill $SSH_PID 2>/dev/null
        return 1
    fi

    echo "System up and running. Share mounted at /Drive"
    echo "Press Ctrl C to exit"
    return 0
}

while true; do
    if ! connect_tunnel; then
        echo "Retrying connection in 10 seconds..."
        sleep 10
        continue
    fi

    while true; do
        sleep 5

        if ! kill -0 $SSH_PID 2>/dev/null; then
            echo "SSH tunnel dropped. Reconnecting..."
            break
        fi

        if ! stat /Drive &>/dev/null; then
            echo "Mount unresponsive. Reconnecting..."
            sudo umount -l /Drive 2>/dev/null
            kill $SSH_PID 2>/dev/null
            break
        fi
    done
done