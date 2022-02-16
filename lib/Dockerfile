FROM mhart/alpine-node:10

WORKDIR /app

RUN apk add --no-cache --update tzdata curl jq python py2-pip build-base \
  && pip install yq \
  && npm install coffeescript express cors morgan mkdirp bluebird knex @vscode/sqlite3 moment \
  && npm cache clean --force \
  && apk del py2-pip build-base \
  && rm -rf /var/cache/apk/*

COPY server.coffee bgg-api.coffee ./

VOLUME /tmp/bgg

ENV TZ=America/Los_Angeles
EXPOSE 5000
ENV HOST 0.0.0.0
CMD ["./node_modules/.bin/coffee", "server.coffee"]
