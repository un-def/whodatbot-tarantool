FROM tarantool/tarantool:2.2.2 AS build
WORKDIR /opt/whodatbot/
COPY deps.txt /tmp/deps.txt
RUN apk add --no-cache git curl unzip
RUN \
  while read dep; \
  do tarantoolctl rocks install --server=https://luarocks.org "$dep"; \
  done < /tmp/deps.txt
COPY src/whodatbot/ whodatbot/

FROM tarantool/tarantool:2.2.2
WORKDIR /opt/whodatbot/
COPY --from=build /opt/whodatbot/ ./

ENV WHODATBOT_CONFIG_PATH /opt/whodatbot/config.yaml
ENV LUA_PATH '/opt/whodatbot/?.lua;/opt/whodatbot/?/init.lua;;'
CMD ["tarantool", "whodatbot/main.lua"]

LABEL maintainer="un.def <me@undef.im>"
LABEL version="0.1.0"
