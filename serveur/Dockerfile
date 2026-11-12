# Module Home Assistant « Tournée calendriers » (construit sur la Raspberry Pi).
FROM alpine:3.22

ARG BUILD_ARCH=aarch64
ARG POCKETBASE_VERSION=0.40.6
# Empreintes officielles (checksums.txt de la version) : le fichier téléchargé
# est refusé s'il a été modifié.
ARG POCKETBASE_SHA256_ARM64=d22c66ceb67ca92b7d767f36d826e848a276bcfa3c197ead20bf87c42208984f
ARG POCKETBASE_SHA256_AMD64=0e1f609158ed945f809f8a02ae012aa0427129c66ebb63c1aee76f2c0309373f

RUN apk add --no-cache ca-certificates jq tailscale unzip \
 && case "${BUILD_ARCH}" in \
      aarch64) ARCHI=arm64; EMPREINTE="${POCKETBASE_SHA256_ARM64}" ;; \
      amd64) ARCHI=amd64; EMPREINTE="${POCKETBASE_SHA256_AMD64}" ;; \
      *) echo "Architecture non prévue : ${BUILD_ARCH}"; exit 1 ;; \
    esac \
 && wget -q -O /tmp/pocketbase.zip \
      "https://github.com/pocketbase/pocketbase/releases/download/v${POCKETBASE_VERSION}/pocketbase_${POCKETBASE_VERSION}_linux_${ARCHI}.zip" \
 && echo "${EMPREINTE}  /tmp/pocketbase.zip" | sha256sum -c - \
 && mkdir -p /opt/pocketbase \
 && unzip -q /tmp/pocketbase.zip pocketbase -d /opt/pocketbase \
 && rm /tmp/pocketbase.zip

COPY pb_hooks /opt/pocketbase/pb_hooks
COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"]
