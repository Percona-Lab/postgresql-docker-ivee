FROM oraclelinux:9

LABEL org.opencontainers.image.authors="info@percona.com"

RUN dnf -y update; \
    dnf -y install glibc-langpack-en

ENV PPG_MAJOR_VERSION 17
ENV PPG_MINOR_VERSION 0
ENV PPG_VERSION ${PPG_MAJOR_VERSION}.${PPG_MINOR_VERSION}-1
ENV OS_VER el9
ENV FULL_PERCONA_VERSION "${PPG_VERSION}.${OS_VER}"
ENV PPG_REPO testing
ENV PPG_REPO_VERSION "${PPG_MAJOR_VERSION}.${PPG_MINOR_VERSION}"

# check repository package signature in secure way
RUN set -ex; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 4D1BB29D63D98E422B2113B19334A25F8507EFA5 99DB70FAE1D7CE227FB6488205B555B38483C65D; \
    gpg --batch --export --armor 4D1BB29D63D98E422B2113B19334A25F8507EFA5 > ${GNUPGHOME}/PERCONA-PACKAGING-KEY; \
    gpg --batch --export --armor 99DB70FAE1D7CE227FB6488205B555B38483C65D > ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    rpmkeys --import ${GNUPGHOME}/PERCONA-PACKAGING-KEY ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    dnf install -y findutils; \
    curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
    rpmkeys --checksig /tmp/percona-release.rpm; \
    rpm -i /tmp/percona-release.rpm; \
    rm -rf "$GNUPGHOME" /tmp/percona-release.rpm; \
    rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY; \
    percona-release enable ppg-${PPG_REPO_VERSION} ${PPG_REPO}; \
    percona-release enable ppg-${PPG_MAJOR_VERSION}-extras experimental;

RUN set -ex; \
    dnf -y update; \
    dnf -y install \
        bind-utils \
        gettext \
        hostname \
        perl \
        tar \
        bzip2 \
        lz4 \
        procps-ng; \
    dnf -y install  \
        nss_wrapper \
        shadow-utils \
        libpq \
        libedit; \
    dnf clean all

# the numeric UID is needed for OpenShift
RUN useradd -u 1001 -r -g 0 -s /sbin/nologin \
            -c "Default Application User" postgres

ENV PGDATA /data/db

RUN set -ex; \
    dnf install -y \
        percona-postgresql${PPG_MAJOR_VERSION}-server-${FULL_PERCONA_VERSION} \
        percona-postgresql${PPG_MAJOR_VERSION}-contrib-${FULL_PERCONA_VERSION} \
        percona-postgresql-common \
        percona-pg_stat_monitor${PPG_MAJOR_VERSION} \
        percona-pg_repack${PPG_MAJOR_VERSION} \
        percona-pgaudit${PPG_MAJOR_VERSION} \
        percona-pgaudit${PPG_MAJOR_VERSION}_set_user \
        percona-wal2json${PPG_MAJOR_VERSION} \
	percona-pgvector_${PPG_MAJOR_VERSION} \
	percona-timescaledb_${PPG_MAJOR_VERSION}; \
    dnf clean all; \
    rm -rf /var/cache/dnf /var/cache/yum $PGDATA && mkdir -p $PGDATA /docker-entrypoint-initdb.d; \
    chown -R 1001:0 $PGDATA docker-entrypoint-initdb.d

RUN set -ex; \
    sed -ri "s!^#?(listen_addresses)\s*=\s*\S+.*!\1 = '*'!" /usr/pgsql-${PPG_MAJOR_VERSION}/share/postgresql.conf.sample; \
    grep -F "listen_addresses = '*'" /usr/pgsql-${PPG_MAJOR_VERSION}/share/postgresql.conf.sample

COPY LICENSE /licenses/LICENSE.Dockerfile
RUN cp /usr/share/doc/percona-postgresql${PPG_MAJOR_VERSION}/COPYRIGHT /licenses/COPYRIGHT.PostgreSQL

ENV GOSU_VERSION=1.11
RUN set -eux; \
    curl -Lf -o /usr/bin/gosu https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64; \
    curl -Lf -o /usr/bin/gosu.asc https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64.asc; \
    \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
    gpg --batch --verify /usr/bin/gosu.asc /usr/bin/gosu; \
    rm -rf "$GNUPGHOME" /usr/bin/gosu.asc; \
    \
    chmod +x /usr/bin/gosu; \
    curl -f -o /licenses/LICENSE.gosu https://raw.githubusercontent.com/tianon/gosu/${GOSU_VERSION}/LICENSE

COPY entrypoint.sh /entrypoint.sh

VOLUME ["/data/db"]

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 5432

USER 1001

CMD ["postgres"]
