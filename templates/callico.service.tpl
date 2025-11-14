[Unit]
Description=Callico Docker Stack
Requires=docker.service
After=docker.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=__TARGET_DIR__
ExecStart=/usr/bin/env docker compose up -d
ExecStop=/usr/bin/env docker compose down
TimeoutStartSec=300
TimeoutStopSec=120

[Install]
WantedBy=multi-user.target
