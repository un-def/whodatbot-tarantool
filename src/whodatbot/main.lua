local fio = require('fio')
local log = require('log')
local yaml = require('yaml')
local console = require('console')
local WhoDatBot
WhoDatBot = require('whodatbot.bot').WhoDatBot
local die
die = function(...)
  log.error(...)
  return os.exit(1)
end
local configure_proxy
configure_proxy = function(proxy_url)
  os.setenv('http_proxy', proxy_url)
  return os.setenv('https_proxy', proxy_url)
end
local load_config
load_config = function()
  local config_path = os.getenv('WHODATBOT_CONFIG_PATH')
  if config_path then
    config_path = fio.abspath(config_path)
  else
    config_path = fio.pathjoin(fio.cwd(), 'config.yaml')
  end
  log.info('using config: %s', config_path)
  if not fio.path.is_file(config_path) then
    die('%s does not exist or is not a file', config_path)
  end
  local fh, err = fio.open(config_path)
  if not fh then
    die(err)
  end
  local config_content = fh:read()
  if not config_content then
    die('error reading config file')
  end
  local ok, config = pcall(yaml.decode, config_content)
  if not ok then
    die('error parsing config file: %s', config)
  end
  return config
end
local config = load_config()
local console_socket = config.console_socket
if console_socket then
  console.listen(fio.abspath(console_socket))
end
if config.proxy then
  configure_proxy(config.proxy)
end
local api_token = config.api_token
if not api_token then
  die('api_token is not set')
end
local work_dir = config.work_dir
if not work_dir then
  die('work_dir is not set')
end
box.cfg({
  work_dir = fio.abspath(work_dir)
})
local bot = WhoDatBot(api_token, false)
local ok, err = bot:init()
if not ok then
  die(err)
end
log.info('bot username: %s', bot.username)
return bot:run()
