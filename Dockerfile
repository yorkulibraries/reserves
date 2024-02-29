# Dockerfile for dev purposes:
FROM ruby:3.1.2-alpine3.16
LABEL maintainer="Luis Zambrano <lzambra2@yorku.ca>"

RUN bundle config --global frozen 1

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app
  
RUN apk update && apk upgrade && \
    apk --no-cache add \
    linux-headers bash git curl tar \
    clang \
    mariadb-dev \
    shared-mime-info \
    file \
    build-base \
    patch \
    ruby-dev \
    zlib-dev \
    xz \
    nodejs tzdata \
    imagemagick && rm -rf /var/lib/apt/lists/*

COPY Gemfile /usr/src/app/
COPY Gemfile.lock /usr/src/app/

RUN bundle install --without test production
