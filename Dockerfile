FROM ruby:2.3-slim
MAINTAINER Georgi Kiryakov <george.kiryakov@gmail.com>

RUN apt-get update && apt-get install -qq -y build-essential --fix-missing --no-install-recommends

ENV INSTALL_PATH /marco
RUN mkdir -p $INSTALL_PATH

WORKDIR $INSTALL_PATH

COPY Gemfile Gemfile
RUN bundle install

COPY . .

VOLUME ["$INSTALL_PATH"]

CMD ["echo", "Hello world"]