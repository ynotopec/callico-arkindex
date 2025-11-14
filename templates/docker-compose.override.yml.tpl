services:
  callico:
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.callico.rule=Host(`__DOMAIN__`)"
      - "traefik.http.routers.callico.entrypoints=websecure"
      - "traefik.http.routers.callico.tls.certresolver=letsencrypt"
      - "traefik.http.middlewares.callico-https-redirect.redirectscheme.scheme=https"
      - "traefik.http.routers.callico-http.rule=Host(`__DOMAIN__`)"
      - "traefik.http.routers.callico-http.entrypoints=web"
      - "traefik.http.routers.callico-http.middlewares=callico-https-redirect"
      - "traefik.http.services.callico.loadbalancer.server.port=8000"
    networks:
      - callico-public

  traefik:
    image: traefik:v3.1
    command:
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.web.http.redirections.entryPoint.to=websecure"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencrypt.acme.email=__LE_EMAIL__"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
      - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "./letsencrypt:/letsencrypt"
    networks:
      - callico-public
    restart: unless-stopped

networks:
  callico-public:
    external: false
