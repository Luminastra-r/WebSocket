FROM ghcr.io/xtls/xray-core:latest

WORKDIR /usr/local/etc/xray

EXPOSE 443

CMD ["run", "-config", "/usr/local/etc/xray/config.json"]
