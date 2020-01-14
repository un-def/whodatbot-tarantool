log = require 'log'

import TelegramBot, UPDATE_TYPES from require 'taragram'

import UserInfoStorage, UserInfoHistoryStorage from require 'whodatbot.storage.userinfo'


os_date = os.date
table_insert = table.insert
table_remove = table.remove
table_concat = table.concat


_extract_users = (tbl, accum) ->
    {:is_bot, :id, :first_name} = tbl
    if id and first_name and not is_bot and not accum[id]
        accum[id] = {
            :id
            :first_name
            last_name: tbl.last_name
            username: tbl.username
        }
        return
    for _, value in pairs tbl
        if type(value) == 'table'
            _extract_users value, accum
    return accum

extract_users = (msg) ->
    accum = {}
    _extract_users msg, accum
    return [u for _, u in pairs accum]


user_info_fields = {
    {'tg_id', 'ID'}
    {'first_name', 'First Name'}
    {'last_name', 'Last Name'}
    {'username', 'Username'}
}


NIL_PLACEHOLDER = '(not set)'


format_date = (unix_time) -> os_date '%Y-%m-%d', unix_time


format_user_info = (user_info) ->
    strings = {}
    for {field_name, verbose_name} in *user_info_fields
        value = user_info[field_name]
        if value
            table_insert strings, '%s: %s'\format(verbose_name, value)
    return table_concat strings, '\n'


user_info_diff = (user_info_old, user_info_new) ->
    lines = {'[%s] changes: '\format(format_date user_info_new.datetime)}
    for {field_name, verbose_name} in *user_info_fields
        old = user_info_old[field_name]
        new = user_info_new[field_name]
        if old != new
            old = old or NIL_PLACEHOLDER
            new = new or NIL_PLACEHOLDER
            table_insert lines, '%s: %s → %s'\format(verbose_name, old, new)
    table_insert lines, ''
    return table_concat lines, '\n'


_format_history_first_last = (user_info, first_last) ->
    lines = {
        '[%s] %s seen info:'\format(format_date(user_info.datetime), first_last)
        format_user_info user_info
        ''
    }
    return table_concat lines, '\n'


format_history = (history) ->
    parts = {}
    if #history > 1
        table_insert parts, _format_history_first_last(history[1], 'last')
        local prev_user_info
        for user_info in *history
            if prev_user_info
                table_insert parts, user_info_diff(user_info, prev_user_info)
            prev_user_info = user_info
    table_insert parts, _format_history_first_last(history[#history], 'first')
    return table_concat parts, '\n'


help_message = [[
/whois — get your user info
/whoami — same as /whois
/whois <id> — get user info for user with id <id>
/history — get your user info history
/history <id> — get user info history for user with id <id>
]]


class CommandRegistry

    new: =>
        @_registry = {}

    __call: (...) => @register ...

    register: (...) =>
        -- pattern, [pattern, ...], func
        patterns = {...}
        func = table_remove patterns
        for pattern in *patterns
            pattern = '^/%s$'\format(pattern)
            table_insert @_registry, {pattern, func}
        return func

    get_handler: (text) =>
        for {pattern, func} in *@_registry
            matches = {string.match(text, pattern)}
            if matches[1]
                return func, matches
        return nil


cmd = CommandRegistry()


class WhoDatBot

    cmd: cmd

    allowed_updates: {UPDATE_TYPES.MESSAGE, UPDATE_TYPES.CALLBACK_QUERY}

    new: (api_token, recreate) =>
        @bot = TelegramBot(api_token)
        @user_info = UserInfoStorage(recreate)
        @user_info_history = UserInfoHistoryStorage(recreate)

    init: =>
        resp, err = @bot\get_me!
        if not resp
            return false, err
        @username = resp.username
        return true

    run: =>
        update_channel = @bot\start_polling 'polling_fiber', @allowed_updates
        while true
            @_process_update update_channel

    _process_update: (channel) =>
        update = channel\get!
        if not update
            -- what?!
            log.warn 'no update'
            return
        update_type = update.type
        update_object = update.object
        log.info 'new update with type %s', update_type
        switch update_type
            when UPDATE_TYPES.MESSAGE
                @_process_message update_object
            when UPDATE_TYPES.CALLBACK_QUERY
                @_process_callback_query update_object
            else
                log.warn 'unexpected update'

    _process_message: (message) =>
        log.info message

        is_private_chat = message.chat.id > 0
        is_forward = message.forward_date ~= nil
        from_user_id = message.from.id
        chat_id = message.chat.id
        forward_sender_name = message.forward_sender_name

        need_to_respond = is_private_chat and is_forward

        if forward_sender_name
            log.info 'hidden user: %s', forward_sender_name
            if need_to_respond
                @bot\send_message chat_id, '%s has hidden their account'\format(forward_sender_name)
                need_to_respond = false

        for user in *extract_users message
            {:id, :first_name, :last_name, :username} = user

            box.begin!
            upserted = @user_info\maybe_upsert id, first_name, last_name, username
            if upserted
                @user_info_history\insert id, first_name, last_name, username
            box.commit!

            if id == from_user_id
                log.info 'user (sender): %s', id
            else
                log.info 'user: %s', id
                if need_to_respond
                    @whois message, id
                    need_to_respond = false

        text = message.text
        if is_private_chat and not is_forward and text and text\sub(1, 1) == '/'
            func, args = @cmd\get_handler text
            if not func
                @bot\send_message chat_id, 'Unknown command. See /help'
            else
                func @, message, unpack args

        if need_to_respond
            @bot\send_message chat_id, 'There is no user in the message'

    _process_callback_query: (callback_query) =>
        log.info callback_query
        callback_data = callback_query.data
        log.info 'callback_query.data: %s', callback_data
        @bot\answer_callback_query callback_query.id
        callback_type, payload = callback_data\match '^(%a+):(%w+)$'
        if not callback_type
            log.warn 'unknown callback_query.data', callback_data
        if callback_type == 'history'
            user_id = tonumber payload
            if not user_id
                log.warn 'failed to parse user_id: %s', payload
                return
            @history callback_query.message, user_id
        else
            log.warn 'unknown callback type: %s', callback_type

    start: cmd 'start (%d+)', (message, secret) =>
        log.info 'start with secret %s', secret

    help: cmd 'help', 'start', (message) =>
        @bot\send_message message.chat.id, help_message

    whois_self: cmd 'whois', 'whoami', (message) => @whois message, message.from.id

    whois: cmd 'whois (%d+)', (message, user_id) =>
        chat_id = message.chat.id
        user_info = @user_info\get tonumber user_id
        if not user_info
            @bot\send_message chat_id, 'no info'
            return
        button_history = {
            text: 'History'
            callback_data: 'history:%s'\format(user_id)
        }
        inline_keyboard = {
            {button_history}
        }
        text = format_user_info user_info
        @bot\send_message chat_id, text, {
            reply_markup: {
                inline_keyboard: inline_keyboard
            }
        }

    history_self: cmd 'history', (message) => @history message, message.from.id

    history: cmd 'history (%d+)', (message, user_id) =>
        chat_id = message.chat.id
        history = @user_info_history\get tonumber(user_id), true
        if #history == 0
            @bot\send_message chat_id, 'No user info'
        else
            @bot\send_message chat_id, format_history history


:WhoDatBot, :extract_users
