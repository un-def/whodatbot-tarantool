local _seq_qualname
_seq_qualname = function(space_name, seq_name)
  return ('%s__%s__seq'):format(space_name, seq_name)
end
local _copy_options
_copy_options = function(options)
  if not options then
    return { }
  end
  local _tbl_0 = { }
  for k, v in pairs(options) do
    _tbl_0[k] = v
  end
  return _tbl_0
end
local _fix_index_options
_fix_index_options = function(space_name, index_options)
  index_options = _copy_options(index_options)
  local sequence = index_options.sequence
  if sequence then
    index_options.sequence = _seq_qualname(space_name, sequence)
  end
  return index_options
end
local atomic
atomic = function(fn)
  return function(...)
    local in_txn = box.is_in_txn()
    local savepoint
    if not in_txn then
      box.begin()
    else
      savepoint = box.savepoint()
    end
    local ok, res, err = pcall(fn, ...)
    if ok and res then
      if not in_txn then
        box.commit()
      end
    elseif in_txn then
      box.rollback_to_savepoint(savepoint)
    else
      box.rollback()
    end
    return res, err
  end
end
local Storage
do
  local _class_0
  local _base_0 = { }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, recreate)
      if recreate == nil then
        recreate = false
      end
      local space_name = self.name
      local space = box.space[space_name]
      if space then
        if not recreate then
          self.space = space
          return
        end
        space:drop()
      end
      local options = _copy_options(self.options)
      if not options.field_count then
        options.field_count = #self.fields
      end
      space = box.schema.space.create(space_name, options)
      space:format(self.fields)
      if self.sequences then
        for seq_name, seq_options in pairs(self.sequences) do
          seq_name = _seq_qualname(space_name, seq_name)
          seq_options = _copy_options(seq_options)
          seq_options.if_not_exists = true
          box.schema.sequence.create(seq_name, seq_options)
        end
      end
      local primary_idx_options = self.indexes.primary
      assert(primary_idx_options, 'no primary index')
      primary_idx_options = _fix_index_options(space_name, primary_idx_options)
      space:create_index('primary', primary_idx_options)
      for idx_name, idx_options in pairs(self.indexes) do
        if idx_name ~= 'primary' then
          idx_options = _fix_index_options(space_name, idx_options)
          space:create_index(idx_name, idx_options)
        end
      end
      self.space = space
    end,
    __base = _base_0,
    __name = "Storage"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Storage = _class_0
end
return {
  Storage = Storage,
  atomic = atomic
}
