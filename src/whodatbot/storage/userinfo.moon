import Storage, atomic from require 'whodatbot.storage.base'
import NULL from require 'msgpack'
import time from require 'clock'


floor = math.floor


is_user_info_changed = (old_info, new_info) ->
    assert #old_info == #new_info
    for i = 1, #old_info
        if old_info[i] ~= new_info[i]
            return true
    return false


class UserInfoStorage extends Storage

    name: 'user_info'

    options:
        engine: 'vinyl'

    fields: {
        {name: 'tg_id', type: 'unsigned'}
        {name: 'first_name', type: 'string'}
        {name: 'last_name', type: 'string', is_nullable: true}
        {name: 'username', type: 'string', is_nullable: true}
    }

    indexes:
        primary:
            parts: {'tg_id'}
            type: 'tree'
            unique: true

    maybe_upsert: atomic (tg_id, first_name, last_name=NULL, username=NULL) =>
        old_info = @space\get tg_id
        new_info = {tg_id, first_name, last_name, username}
        if not old_info
            @space\insert new_info
            return true
        if is_user_info_changed old_info, new_info
            @space\replace new_info
            return true
        return false

    get: (tg_id) => @space\get tg_id


class UserInfoHistoryStorage extends Storage

    name: 'user_info_history'

    options:
        engine: 'vinyl'

    fields: {
        {name: 'id', type: 'unsigned'}
        {name: 'datetime', type: 'unsigned'}
        {name: 'tg_id', type: 'unsigned'}
        {name: 'first_name', type: 'string'}
        {name: 'last_name', type: 'string', is_nullable: true}
        {name: 'username', type: 'string', is_nullable: true}
    }

    indexes:
        primary:
            parts: {'id'}
            type: 'tree'
            unique: true
            sequence: 'auto_id'
        tg_id:
            parts: {'tg_id'}
            type: 'tree'
            unique: false

    sequences:
        auto_id: {}

    insert: atomic (tg_id, first_name, last_name=NULL, username=NULL) =>
        now = floor time!
        @space\insert {NULL, now, tg_id, first_name, last_name, username}
        return true

    get: (tg_id, reverse) =>
        options = nil
        if reverse
            options = {iterator: 'REQ'}
        @space.index.tg_id\select tg_id, options


:UserInfoStorage, :UserInfoHistoryStorage
