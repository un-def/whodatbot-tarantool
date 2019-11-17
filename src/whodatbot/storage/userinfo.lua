local Storage, atomic
do
  local _obj_0 = require('whodatbot.storage.base')
  Storage, atomic = _obj_0.Storage, _obj_0.atomic
end
local NULL
NULL = require('msgpack').NULL
local time
time = require('clock').time
local floor = math.floor
local is_user_info_changed
is_user_info_changed = function(old_info, new_info)
  assert(#old_info == #new_info)
  for i = 1, #old_info do
    if old_info[i] ~= new_info[i] then
      return true
    end
  end
  return false
end
local UserInfoStorage
do
  local _class_0
  local _parent_0 = Storage
  local _base_0 = {
    name = 'user_info',
    options = {
      engine = 'vinyl'
    },
    fields = {
      {
        name = 'tg_id',
        type = 'unsigned'
      },
      {
        name = 'first_name',
        type = 'string'
      },
      {
        name = 'last_name',
        type = 'string',
        is_nullable = true
      },
      {
        name = 'username',
        type = 'string',
        is_nullable = true
      }
    },
    indexes = {
      primary = {
        parts = {
          'tg_id'
        },
        type = 'tree',
        unique = true
      }
    },
    maybe_upsert = atomic(function(self, tg_id, first_name, last_name, username)
      if last_name == nil then
        last_name = NULL
      end
      if username == nil then
        username = NULL
      end
      local old_info = self.space:get(tg_id)
      local new_info = {
        tg_id,
        first_name,
        last_name,
        username
      }
      if not old_info then
        self.space:insert(new_info)
        return true
      end
      if is_user_info_changed(old_info, new_info) then
        self.space:replace(new_info)
        return true
      end
      return false
    end),
    get = function(self, tg_id)
      return self.space:get(tg_id)
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "UserInfoStorage",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  UserInfoStorage = _class_0
end
local UserInfoHistoryStorage
do
  local _class_0
  local _parent_0 = Storage
  local _base_0 = {
    name = 'user_info_history',
    options = {
      engine = 'vinyl'
    },
    fields = {
      {
        name = 'id',
        type = 'unsigned'
      },
      {
        name = 'datetime',
        type = 'unsigned'
      },
      {
        name = 'tg_id',
        type = 'unsigned'
      },
      {
        name = 'first_name',
        type = 'string'
      },
      {
        name = 'last_name',
        type = 'string',
        is_nullable = true
      },
      {
        name = 'username',
        type = 'string',
        is_nullable = true
      }
    },
    indexes = {
      primary = {
        parts = {
          'id'
        },
        type = 'tree',
        unique = true,
        sequence = 'auto_id'
      },
      tg_id = {
        parts = {
          'tg_id'
        },
        type = 'tree',
        unique = false
      }
    },
    sequences = {
      auto_id = { }
    },
    insert = atomic(function(self, tg_id, first_name, last_name, username)
      if last_name == nil then
        last_name = NULL
      end
      if username == nil then
        username = NULL
      end
      local now = floor(time())
      self.space:insert({
        NULL,
        now,
        tg_id,
        first_name,
        last_name,
        username
      })
      return true
    end),
    get = function(self, tg_id)
      return self.space.index.tg_id:select(tg_id)
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "UserInfoHistoryStorage",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  UserInfoHistoryStorage = _class_0
end
return {
  UserInfoStorage = UserInfoStorage,
  UserInfoHistoryStorage = UserInfoHistoryStorage
}
