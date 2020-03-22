fio = require 'fio'
log = require 'log'
yaml = require 'yaml'
console = require 'console'

import WhoDatBot from require 'whodatbot.bot'


die = (...) ->
    log.error ...
    os.exit 1


configure_proxy = (proxy_url) ->
    os.setenv 'http_proxy', proxy_url
    os.setenv 'https_proxy', proxy_url


load_config = ->
    config_path = os.getenv 'WHODATBOT_CONFIG_PATH'
    if config_path
        config_path = fio.abspath config_path
    else
        config_path = fio.pathjoin fio.cwd!, 'config.yaml'
    log.info 'using config: %s', config_path
    if not fio.path.is_file config_path
        die '%s does not exist or is not a file', config_path
    fh, err = fio.open config_path
    if not fh
        die err
    config_content = fh\read!
    if not config_content
        die 'error reading config file'
    ok, config = pcall yaml.decode, config_content
    if not ok
        die 'error parsing config file: %s', config
    return config


config = load_config!


console_socket = config.console_socket
if console_socket
    console.listen fio.abspath console_socket


if config.proxy
    configure_proxy config.proxy


api_token = config.api_token
if not api_token
    die 'api_token is not set'


box_config = config.box
if not box_config
    die 'box config not found'
work_dir = box_config.work_dir
if not work_dir
    die 'box.work_dir is not set'
box_config.work_dir = fio.abspath work_dir
box.cfg box_config


bot = WhoDatBot(api_token, false)
ok, err = bot\init!
if not ok
    die err
log.info 'bot username: %s', bot.username
bot\run!
