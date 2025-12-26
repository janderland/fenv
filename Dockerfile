FROM debian:12

RUN apt-get update &&\
    apt-get install --no-install-recommends -y \
      build-essential=12.9 \
      ca-certificates=20* \
      git=1:2.39.* \
      curl=7.88.* &&\
    apt-get clean &&\
    rm -rf /var/lib/apt/lists/*

ARG SHELLCHECK_URL
RUN curl -Lo /shellcheck.tar.xz $SHELLCHECK_URL &&\
    tar -xf /shellcheck.tar.xz &&\
    mv /shellcheck-*/shellcheck /usr/local/bin &&\
    rm -r /shellcheck.tar.xz /shellcheck-*

ARG HADOLINT_URL
RUN curl -Lo /usr/local/bin/hadolint $HADOLINT_URL &&\
    chmod +x /usr/local/bin/hadolint

ARG JP_URL
RUN curl -Lo /usr/local/bin/jp $JP_URL &&\
    chmod +x /usr/local/bin/jp

ARG FDB_LIB_URL
RUN curl -Lo /fdb.deb $FDB_LIB_URL &&\
    dpkg -i /fdb.deb &&\
    rm /fdb.deb

# Configure git so it allows any user to run git commands
# on the /src directory. This allows the user which runs
# CI to be different from the user which built the Docker
# image.
RUN git config --global --add safe.directory /src

COPY shim.sh /shim.sh

WORKDIR /src
ENTRYPOINT ["/shim.sh"]
