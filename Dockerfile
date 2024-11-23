FROM ruby:3.1.4-bullseye

WORKDIR /app

ARG NODE_VER
ENV NODE_VER $NODE_VER

ADD https://deb.nodesource.com/setup_${NODE_VER:-lts}.x  /tmp/setup_nodejs.x 
RUN chmod a+x /tmp/setup_nodejs.x 
RUN /tmp/setup_nodejs.x 

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
build-essential curl git nodejs vim sqlite3 chromium chromium-driver libvips python default-mysql-client

RUN npm install --global yarn

ADD https://raw.githubusercontent.com/yorkulibraries/docker-rails/main/rt.sh /usr/local/bin/rt
RUN chmod a+x /usr/local/bin/rt

ADD https://raw.githubusercontent.com/yorkulibraries/docker-rails/main/rts.sh /usr/local/bin/rts
RUN chmod a+x /usr/local/bin/rts
