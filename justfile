project := 'whodatbot'

export PATH := `echo "$(pwd)/.rocks/bin:$PATH"`
export LUA_PATH := 'src/?.lua;src/?/init.lua;;'
rocksinstall := 'tarantoolctl rocks install --server=https://luarocks.org'

_list:
  @just --list

install-deps:
  while read dep; do {{rocksinstall}} "$dep"; done < deps.txt

install-dev-deps: install-deps
  while read dep; do {{rocksinstall}} "$dep"; done < dev.deps.txt

build:
  moonc src/
  find src/ -type f -name '*.lua' -exec sed --in-place 's/[[:space:]]\+$//' {} +

watch: build
  moonc src/ -w

lint: build
  find src/ -type f -name '*.moon' -print -exec moonpick {} +
  luacheck src/

test: build
  @tarantool -e "require'busted.runner'{standalone=false};os.exit()"

connect:
  #!/bin/sh
  socket=$(yq read config.yaml console_socket) || exit 1
  [ "${socket}" = 'null' ] && exit 2
  exec tarantoolctl connect "$(readlink -f "${socket}")"

run: build
  mkdir -p db
  tarantool src/{{project}}/main.lua
