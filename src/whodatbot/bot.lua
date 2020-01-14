local log = require('log')
local TelegramBot, UPDATE_TYPES
do
  local _obj_0 = require('taragram')
  TelegramBot, UPDATE_TYPES = _obj_0.TelegramBot, _obj_0.UPDATE_TYPES
end
local UserInfoStorage, UserInfoHistoryStorage
do
  local _obj_0 = require('whodatbot.storage.userinfo')
  UserInfoStorage, UserInfoHistoryStorage = _obj_0.UserInfoStorage, _obj_0.UserInfoHistoryStorage
end
local os_date = os.date
local table_insert = table.insert
local table_remove = table.remove
local table_concat = table.concat
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
local user_info_fields = {
  {
    'tg_id',
    'ID'
  },
  {
    'first_name',
    'First Name'
  },
  {
    'last_name',
    'Last Name'
  },
  {
    'username',
    'Username'
  }
}
local NIL_PLACEHOLDER = '(not set)'
local format_date
format_date = function(unix_time)
  return os_date('%Y-%m-%d', unix_time)
end
local format_user_info
format_user_info = function(user_info)
  local strings = { }
  for _index_0 = 1, #user_info_fields do
    local _des_0 = user_info_fields[_index_0]
    local field_name, verbose_name
    field_name, verbose_name = _des_0[1], _des_0[2]
    local value = user_info[field_name]
    if value then
      table_insert(strings, ('%s: %s'):format(verbose_name, value))
    end
  end
  return table_concat(strings, '\n')
end
local user_info_diff
user_info_diff = function(user_info_old, user_info_new)
  local lines = {
    ('[%s] changes: '):format(format_date(user_info_new.datetime))
  }
  for _index_0 = 1, #user_info_fields do
    local _des_0 = user_info_fields[_index_0]
    local field_name, verbose_name
    field_name, verbose_name = _des_0[1], _des_0[2]
    local old = user_info_old[field_name]
    local new = user_info_new[field_name]
    if old ~= new then
      old = old or NIL_PLACEHOLDER
      new = new or NIL_PLACEHOLDER
      table_insert(lines, ('%s: %s → %s'):format(verbose_name, old, new))
    end
  end
  table_insert(lines, '')
  return table_concat(lines, '\n')
end
local _format_history_first_last
_format_history_first_last = function(user_info, first_last)
  local lines = {
    ('[%s] %s seen info:'):format(format_date(user_info.datetime), first_last),
    format_user_info(user_info),
    ''
  }
  return table_concat(lines, '\n')
end
local format_history
format_history = function(history)
  local parts = { }
  if #history > 1 then
    table_insert(parts, _format_history_first_last(history[1], 'last'))
    local prev_user_info
    for _index_0 = 1, #history do
      local user_info = history[_index_0]
      if prev_user_info then
        table_insert(parts, user_info_diff(user_info, prev_user_info))
      end
      prev_user_info = user_info
    end
  end
  table_insert(parts, _format_history_first_last(history[#history], 'first'))
  return table_concat(parts, '\n')
end
local help_message = [[/whois — get your user info
/whoami — same as /whois
/whois <id> — get user info for user with id <id>
/history — get your user info history
/history <id> — get user info history for user with id <id>
]]
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
    allowed_updates = {
      UPDATE_TYPES.MESSAGE,
      UPDATE_TYPES.CALLBACK_QUERY
    },
    init = function(self)
      local resp, err = self.bot:get_me()
      if not resp then
        return false, err
      end
      self.username = resp.username
      return true
    end,
    run = function(self)
      local update_channel = self.bot:start_polling('polling_fiber', self.allowed_updates)
      while true do
        self:_process_update(update_channel)
      end
    end,
    _process_update = function(self, channel)
      local update = channel:get()
      if not update then
        log.warn('no update')
        return
      end
      local update_type = update.type
      local update_object = update.object
      log.info('new update with type %s', update_type)
      local _exp_0 = update_type
      if UPDATE_TYPES.MESSAGE == _exp_0 then
        return self:_process_message(update_object)
      elseif UPDATE_TYPES.CALLBACK_QUERY == _exp_0 then
        return self:_process_callback_query(update_object)
      else
        return log.warn('unexpected update')
      end
    end,
    _process_message = function(self, message)
      log.info(message)
      local is_private_chat = message.chat.id > 0
      local is_forward = message.forward_date ~= nil
      local from_user_id = message.from.id
      local chat_id = message.chat.id
      local forward_sender_name = message.forward_sender_name
      local need_to_respond = is_private_chat and is_forward
      if forward_sender_name then
        log.info('hidden user: %s', forward_sender_name)
        if need_to_respond then
          self.bot:send_message(chat_id, ('%s has hidden their account'):format(forward_sender_name))
          need_to_respond = false
        end
      end
      local _list_0 = extract_users(message)
      for _index_0 = 1, #_list_0 do
        local user = _list_0[_index_0]
        local id, first_name, last_name, username
        id, first_name, last_name, username = user.id, user.first_name, user.last_name, user.username
        box.begin()
        local upserted = self.user_info:maybe_upsert(id, first_name, last_name, username)
        if upserted then
          self.user_info_history:insert(id, first_name, last_name, username)
        end
        box.commit()
        if id == from_user_id then
          log.info('user (sender): %s', id)
        else
          log.info('user: %s', id)
          if need_to_respond then
            self:whois(message, id)
            need_to_respond = false
          end
        end
      end
      local text = message.text
      if is_private_chat and not is_forward and text and text:sub(1, 1) == '/' then
        local func, args = self.cmd:get_handler(text)
        if not func then
          self.bot:send_message(chat_id, 'Unknown command. See /help')
        else
          func(self, message, unpack(args))
        end
      end
      if need_to_respond then
        return self.bot:send_message(chat_id, 'There is no user in the message')
      end
    end,
    _process_callback_query = function(self, callback_query)
      log.info(callback_query)
      local callback_data = callback_query.data
      log.info('callback_query.data: %s', callback_data)
      self.bot:answer_callback_query(callback_query.id)
      local callback_type, payload = callback_data:match('^(%a+):(%w+)$')
      if not callback_type then
        log.warn('unknown callback_query.data', callback_data)
      end
      if callback_type == 'history' then
        local user_id = tonumber(payload)
        if not user_id then
          log.warn('failed to parse user_id: %s', payload)
          return
        end
        return self:history(callback_query.message, user_id)
      else
        return log.warn('unknown callback type: %s', callback_type)
      end
    end,
    start = cmd('start (%d+)', function(self, message, secret)
      return log.info('start with secret %s', secret)
    end),
    help = cmd('help', 'start', function(self, message)
      return self.bot:send_message(message.chat.id, help_message)
    end),
    whois_self = cmd('whois', 'whoami', function(self, message)
      return self:whois(message, message.from.id)
    end),
    whois = cmd('whois (%d+)', function(self, message, user_id)
      local chat_id = message.chat.id
      local user_info = self.user_info:get(tonumber(user_id))
      if not user_info then
        self.bot:send_message(chat_id, 'no info')
        return
      end
      local button_history = {
        text = 'History',
        callback_data = ('history:%s'):format(user_id)
      }
      local inline_keyboard = {
        {
          button_history
        }
      }
      local text = format_user_info(user_info)
      return self.bot:send_message(chat_id, text, {
        reply_markup = {
          inline_keyboard = inline_keyboard
        }
      })
    end),
    history_self = cmd('history', function(self, message)
      return self:history(message, message.from.id)
    end),
    history = cmd('history (%d+)', function(self, message, user_id)
      local chat_id = message.chat.id
      local history = self.user_info_history:get(tonumber(user_id), true)
      if #history == 0 then
        return self.bot:send_message(chat_id, 'No user info')
      else
        return self.bot:send_message(chat_id, format_history(history))
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
