FROM denoland/deno:alpine

WORKDIR /app
COPY . .
RUN apk add zsh jq \
      # for updated `/usr/bin/env -S`
      coreutils \
      # for host, dig
      bind-tools \
      # for telnet
      busybox-extras

CMD ./index.js
