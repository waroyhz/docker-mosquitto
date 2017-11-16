FROM debian:jessie

MAINTAINER Thomas Kerpe <toke@toke.de>

# Build-time metadata as defined at http://label-schema.org
ARG BUILD_DATE
ARG VCS_REF
LABEL org.label-schema.build-date=$BUILD_DATE \
    org.label-schema.docker.dockerfile="/Dockerfile" \
    org.label-schema.license="BSD 3-Clause" \
    org.label-schema.name="docker-mosquitto" \
    org.label-schema.url="https://hub.docker.com/r/toke/mosquitto/" \
    org.label-schema.vcs-ref=$VCS_REF \
    org.label-schema.vcs-type="Git" \
    org.label-schema.vcs-url="https://github.com/toke/docker-mosquitto"

RUN apt-get update && apt-get install -y wget && \
    wget -q -O - https://repo.mosquitto.org/debian/mosquitto-repo.gpg.key | gpg --import && \
    gpg -a --export 8277CCB49EC5B595F2D2C71361611AE430993623 | apt-key add - && \
    wget -q -O /etc/apt/sources.list.d/mosquitto-jessie.list https://repo.mosquitto.org/debian/mosquitto-jessie.list && \
    apt-get update && apt-get install -y mosquitto mosquitto-clients && \
    adduser --system --disabled-password --disabled-login mosquitto

RUN mkdir -p /mqtt/config /mqtt/data /mqtt/log
COPY config /mqtt/config
RUN chown -R mosquitto:mosquitto /mqtt

# Download the support needed to compile libary
RUN apt-get install -y git g++ gcc make libssl-dev libcurl4-openssl-dev libc-ares-dev uuid-dev libwebsockets-dev wget

# Download mosquitto 1.4.14 source code and compile mosquitto auth plug
RUN export MQTTVER=1.4.14 &&\
    git clone https://github.com/jpmens/mosquitto-auth-plug.git &&\
    wget https://mosquitto.org/files/source/mosquitto-${MQTTVER}.tar.gz && \
    tar -zxvf mosquitto-${MQTTVER}.tar.gz&&\
    cd mosquitto-${MQTTVER} &&\
    sed -i 's/WITH_WEBSOCKETS:=no/WITH_WEBSOCKETS:=yes/g' config.mk &&\
    make && make install &&\
    cd /mosquitto-auth-plug &&\
    cp config.mk.in config.mk &&\
    sed -i 's/BACKEND_MYSQL ?= yes/BACKEND_MYSQL ?= no/g' config.mk &&\
    sed -i 's/BACKEND_HTTP ?= no/BACKEND_HTTP ?= yes/g' config.mk &&\
    sed -i 's/MOSQUITTO_SRC =/MOSQUITTO_SRC =\/mosquitto-${MQTTVER}/g' config.mk &&\
    make && \
    cp auth-plug.so /mqtt &&\
    cd /

VOLUME ["/mqtt/config", "/mqtt/data", "/mqtt/log"]

EXPOSE 1883 9001

ADD docker-entrypoint.sh /usr/bin/

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["/usr/sbin/mosquitto", "-c", "/mqtt/config/mosquitto.conf"]
