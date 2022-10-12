# syntax=docker/dockerfile:1.4

ARG MEMCACHED_VERSION=1.6.17

FROM docker.io/bitnami/minideb:bullseye as builder

COPY prebuildfs /
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY --link --from=ghcr.io/bitcompat/gosu:1.14.0-bullseye-r1 /opt/bitnami/ /opt/bitnami/

RUN install_packages acl ca-certificates curl gzip libc6 libevent-2.1-7 libsasl2-2 libsasl2-modules procps sasl2-bin tar \
  dpkg-dev gcc libc6-dev libevent-dev libio-socket-ssl-perl libsasl2-dev libssl-dev make perl

ARG MEMCACHED_VERSION
ADD --link https://memcached.org/files/memcached-$MEMCACHED_VERSION.tar.gz /opt/src/

ENV PATH="/opt/bitnami/memcached/bin:/opt/bitnami/common/bin:$PATH"
RUN <<EOT bash
    set -ex
	cd /opt/src
	tar -xzf memcached-$MEMCACHED_VERSION.tar.gz

    cd memcached-$MEMCACHED_VERSION

	./configure --build="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" --enable-sasl --enable-sasl-pwdb --enable-tls --prefix=/opt/bitnami/memcached
	make -j$(nproc)
    make install
    rm -rf /opt/bitnami/memcached/share
	memcached -V

    chmod g+rwX /opt/bitnami
EOT

COPY --link rootfs /
ADD --link https://raw.githubusercontent.com/memcached/memcached/master/LICENSE /opt/bitnami/memcached/licenses/memcached-${MEMCACHED_VERSION}.txt

RUN /opt/bitnami/scripts/memcached/postunpack.sh

FROM docker.io/bitnami/minideb:bullseye as stage-0

COPY --from=builder --link /opt/bitnami /opt/bitnami

RUN <<EOT bash
    install_packages ca-certificates procps sasl2-bin libevent-2.1-7 libsasl2-2 libsasl2-modules
    ln -s /opt/bitnami/scripts/memcached/entrypoint.sh /entrypoint.sh
    ln -s /opt/bitnami/scripts/memcached/run.sh /run.sh
EOT

ARG MEMCACHED_VERSION
ARG TARGETARCH
ENV APP_VERSION="${MEMCACHED_VERSION}" \
    BITNAMI_APP_NAME="memcached" \
    PATH="/opt/bitnami/memcached/bin:/opt/bitnami/common/bin:$PATH" \
    HOME="/" \
    OS_ARCH="${TARGETARCH}" \
    OS_FLAVOUR="debian-11" \
    OS_NAME="linux"

LABEL org.opencontainers.image.ref.name="${MEMCACHED_VERSION}-bullseye-r1" \
      org.opencontainers.image.title="memcached" \
      org.opencontainers.image.version="${MEMCACHED_VERSION}"

EXPOSE 11211
USER 1001

ENTRYPOINT [ "/opt/bitnami/scripts/memcached/entrypoint.sh" ]
CMD [ "/opt/bitnami/scripts/memcached/run.sh" ]
