local log = require('log')
local TelegramBot
TelegramBot = require('taragram').TelegramBot
local UserInfoStorage, UserInfoHistoryStorage
do
  local _obj_0 = require('whodatbot.storage.userinfo')
  UserInfoStorage, UserInfoHistoryStorage = _obj_0.UserInfoStorage, _obj_0.UserInfoHistoryStorage
end
local table_insert = table.insert
local table_remove = table.remove
local _extract_users
_extract_users = function(tbl, accum)
  local is_bot, id, first_name
  is_bot, id, first_name = tbl.is_bot, tbl.id, tbl.first_name
  if id and first_name and not is_bot and not accum[id] then
    accum[id] = {
      id = id,
      first_name = first_name,
      last_name = tbl.last_name,
      username = tbl.username
    }
    return
  end
  for _, value in pairs(tbl) do
    if type(value) == 'table' then
      _extract_users(value, accum)
    end
  end
  return accum
end
local extract_users
extract_users = function(msg)
  local accum = { }
  _extract_users(msg, accum)
  local _accum_0 = { }
  local _len_0 = 1
  for _, u in pairs(accum) do
    _accum_0[_len_0] = u
    _len_0 = _len_0 + 1
  end
  return _accum_0
end
local CommandRegistry
do
  local _class_0
  local _base_0 = {
    __call = function(self, ...)
      return self:register(...)
    end,
    register = function(self, ...)
      local patterns = {
        ...
      }
      local func = table_remove(patterns)
      for _index_0 = 1, #patterns do
        local pattern = patterns[_index_0]
        pattern = ('^/%s$'):format(pattern)
        table_insert(self._registry, {
          pattern,
          func
        })
      end
      return func
    end,
    get_handler = function(self, text)
      local _list_0 = self._registry
      for _index_0 = 1, #_list_0 do
        local _des_0 = _list_0[_index_0]
        local pattern, func
        pattern, func = _des_0[1], _des_0[2]
        local matches = {
          string.match(text, pattern)
        }
        if matches[1] then
          return func, matches
        end
      end
      return nil
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self)
      self._registry = { }
    end,
    __base = _base_0,
    __name = "CommandRegistry"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  CommandRegistry = _class_0
end
local cmd = CommandRegistry()
local WhoDatBot
do
  local _class_0
  local _base_0 = {
    cmd = cmd,
    init = function(self)
      local resp, err = self.bot:get_me()
      if not resp then
        return false, err
      end
      self.username = resp.username
      return true
    end,
    run = function(self)
      local message_channel = self.bot:start_polling('polling_fiber')
      while true do
        self:_process_msg(message_channel)
      end
    end,
    _process_msg = function(self, channel)
      local msg = channel:get()
      log.info(msg)
      if not msg then
        return
      end
      local _list_0 = extract_users(msg)
      for _index_0 = 1, #_list_0 do
        local user = _list_0[_index_0]
        log.info('user found: %s', user.id)
        local id, first_name, last_name, username
        id, first_name, last_name, username = user.id, user.first_name, user.last_name, user.username
        box.begin()
        local upserted = self.user_info:maybe_upsert(id, first_name, last_name, username)
        if upserted then
          self.user_info_history:insert(id, first_name, last_name, username)
        end
        box.commit()
      end
      local text = msg.text
      if msg.chat.id > 0 and text and text:sub(1, 1) == '/' then
        local func, args = self.cmd:get_handler(text)
        if not func then
          return self.bot:send_message(msg.chat.id, 'Unknown command. See /help')
        else
          return func(self, msg, unpack(args))
        end
      end
    end,
    start = cmd('start (%d+)', function(self, msg, secret)
      return log.info('start with secret %s', secret)
    end),
    help = cmd('help', 'start', function(self, msg)
      return self.bot:send_message(msg.chat.id, 'no help')
    end),
    whoami = cmd('whoami', function(self, msg)
      local user_info = self.user_info:get(msg.from.id)
      return self.bot:send_message(msg.chat.id, tostring(user_info))
    end),
    whois = cmd('whois (%d+)', function(self, msg, user_id)
      local user_info = self.user_info:get(tonumber(user_id))
      if not user_info then
        return self.bot:send_message(msg.chat.id, 'no info')
      else
        return self.bot:send_message(msg.chat.id, tostring(user_info))
      end
    end),
    history_self = cmd('history', function(self, msg)
      return self:history(msg, msg.from.id)
    end),
    history = cmd('history (%d+)', function(self, msg, user_id)
      user_id = tonumber(user_id)
      local history = self.user_info_history:get(user_id)
      if #history == 0 then
        return self.bot:send_message(msg.chat.id, 'no info')
      else
        local response = table.concat((function()
          local _accum_0 = { }
          local _len_0 = 1
          for _index_0 = 1, #history do
            local e = history[_index_0]
            _accum_0[_len_0] = tostring(e)
            _len_0 = _len_0 + 1
          end
          return _accum_0
        end)(), '\n')
        return self.bot:send_message(msg.chat.id, response)
      end
    end)
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, api_token, recreate)
      self.bot = TelegramBot(api_token)
      self.user_info = UserInfoStorage(recreate)
      self.user_info_history = UserInfoHistoryStorage(recreate)
    end,
    __base = _base_0,
    __name = "WhoDatBot"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  WhoDatBot = _class_0
end
return {
  WhoDatBot = WhoDatBot,
  extract_users = extract_users
}
