### Guide for Setting Up 0G Node Monitoring

#### Step 1: Download the Monitoring Script

Navigate to your home directory and download the monitoring script:
```bash
cd $HOME
wget -O 0g-monitoring.sh https://raw.githubusercontent.com/mART321/0g-monitoring/main/0g-monitoring.sh
```
#### Step 2: Configure Telegram Alerts

1. Open Telegram and find @BotFather to create a new bot.
2. Follow the instructions from @BotFather to obtain your `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID`.

#### Step 3: Edit Script
```bash
nano 0g-monitoring.sh
```
```bash
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
VALIDATOR_RPC_PORT=""
STORAGE_RPC_PORT=""
```
#### If you have only a validator node or only a storage node, simply enter the node's port in the specified place and leave the second one empty; you don't need to delete it)
```bash
VALIDATOR_RPC_PORT=""
STORAGE_RPC_PORT=""
```

#### Step 4: Make the Script Executable

Make the downloaded script executable:
```bash
chmod +x 0g-monitoring.sh
```

#### Step 5: Set Up the Systemd Service

Create and edit the service file:
```bash
sudo tee /etc/systemd/system/monitoring-0g.service > /dev/null <<EOF
[Unit]
Description=0G Node Health Service
After=network-online.target

[Service]
User=$USER
WorkingDirectory=$HOME
ExecStart=/bin/bash $HOME/0g-monitoring.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

#### Step 6: Start the Service

Reload the systemd daemon and enable the service to start on boot:
```bash
sudo systemctl daemon-reload
sudo systemctl enable monitoring-0g
sudo systemctl restart monitoring-0g && sudo journalctl -u monitoring-0g -f
```

#### Removing the Service and Script (if needed)

If you need to remove the service and script, execute the following commands:

Stop and disable the service, then remove the service file and script:
```bash
sudo systemctl stop monitoring-0g
sudo systemctl disable monitoring-0g
sudo rm -rf /etc/systemd/system/monitoring-0g.service
rm ~/0g-monitoring.sh
sudo systemctl daemon-reload
```
