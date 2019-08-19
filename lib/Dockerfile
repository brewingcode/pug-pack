FROM mhart/alpine-node:10

WORKDIR /app

RUN apk add --no-cache --update tzdata curl jq python py2-pip \
  && pip install yq \
  && npm install coffeescript express sanitize-filename cors morgan mkdirp bluebird

COPY server.coffee bgg-api.coffee ./

ENV TZ=America/Los_Angeles
EXPOSE 5000
ENV HOST 0.0.0.0
CMD ["./node_modules/.bin/coffee", "server.coffee"]
