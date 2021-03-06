FROM debian:jessie

# Maintainer
MAINTAINER Silvio Fricke <silvio.fricke@gmail.com>

# update and upgrade
RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends \
	build-essential \
	curl \
	git-core \
	libevent-dev \
	libffi-dev \
	libjpeg-dev \
	libsqlite3-dev \
	libssl-dev \
	pwgen \
	python-pip \
	python-virtualenv \
	python2.7-dev \
	sqlite3 \
	unzip \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# install homerserver template
ADD adds/start.sh /start.sh
RUN chmod a+x /start.sh

# startup configuration
ENTRYPOINT ["/start.sh"]
CMD ["start"]
EXPOSE 8448
VOLUME ["/data"]

# install/upgrade pip
RUN pip install --upgrade pip setuptools

# "git clone" is cached, we need to invalidate the docker cache here
# to use this add a --build-arg INVALIDATEBUILD=$(data) to your docker build
# parameter.
ENV INVALIDATEBUILD=notinvalidated

# installing vector.im with nodejs/npm
RUN curl -sL https://deb.nodesource.com/setup | bash - \
    && apt-get install -y nodejs \
    && npm install -g webpack http-server

ENV BV_VEC=master
ADD https://github.com/vector-im/vector-web/archive/$BV_VEC.zip v.zip
RUN unzip v.zip \
    && rm v.zip \
    && mv vector-web-$BV_VEC vector-web \
    && cd vector-web \
    && npm install \
    && GIT_VEC=$(git ls-remote https://github.com/vector-im/vector-web $BV_VEC | cut -f 1) \
    && echo "vector:  $BV_VEC ($GIT_VEC)" > /synapse.version \
    && npm run build

# install synapse homeserver
ENV BV_SYN=master
ADD https://github.com/matrix-org/synapse/archive/$BV_SYN.zip s.zip
RUN unzip s.zip \
    && rm s.zip \
    && cd /synapse-$BV_SYN \
    && pip install --process-dependency-links . \
    && GIT_SYN=$(git ls-remote https://github.com/matrix-org/synapse $BV_SYN | cut -f 1) \
    && echo "synapse: $BV_SYN ($GIT_SYN)" >> /synapse.version \
    && rm -rf /synapse-$BV_SYN

# install turn-server
ENV BV_TUR=master
ADD https://github.com/coturn/coturn/archive/$BV_TUR.zip c.zip
RUN unzip c.zip \
    && rm c.zip \
    && cd /coturn-$BV_TUR \
    && ./configure \
    && make \
    && make install \
    && GIT_TUR=$(git ls-remote https://github.com/coturn/coturn $BV_TUR | cut -f 1) \
    && echo "coturn:  $BV_TUR ($GIT_TUR)" >> /synapse.version \
    && rm -rf /coturn-$BV_TUR

