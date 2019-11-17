log = require 'log'

import TelegramBot from require 'taragram'

import UserInfoStorage, UserInfoHistoryStorage from require 'whodatbot.storage.userinfo'


table_insert = table.insert
table_remove = table.remove


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
        message_channel = @bot\start_polling 'polling_fiber'
        while true
            @_process_msg message_channel

    _process_msg: (channel) =>
        msg = channel\get!
        log.info msg
        if not msg
            -- what?!
            return
        for user in *extract_users msg
            log.info 'user found: %s', user.id
            {:id, :first_name, :last_name, :username} = user
            box.begin!
            upserted = @user_info\maybe_upsert id, first_name, last_name, username
            if upserted
                @user_info_history\insert id, first_name, last_name, username
            box.commit!
        text = msg.text
        if msg.chat.id > 0 and text and text\sub(1, 1) == '/'
            func, args = @cmd\get_handler text
            if not func
                @bot\send_message msg.chat.id, 'Unknown command. See /help'
            else
                func @, msg, unpack args

    start: cmd 'start (%d+)', (msg, secret) =>
        log.info 'start with secret %s', secret

    help: cmd 'help', 'start', (msg) =>
        @bot\send_message msg.chat.id, 'no help'

    whoami: cmd 'whoami', (msg) =>
        user_info = @user_info\get msg.from.id
        @bot\send_message msg.chat.id, tostring user_info

    whois: cmd 'whois (%d+)', (msg, user_id) =>
        user_info = @user_info\get tonumber user_id
        if not user_info
            @bot\send_message msg.chat.id, 'no info'
        else
            @bot\send_message msg.chat.id, tostring user_info

    history_self: cmd 'history', (msg) => @history msg, msg.from.id

    history: cmd 'history (%d+)', (msg, user_id) =>
        user_id = tonumber user_id
        history = @user_info_history\get user_id
        if #history == 0
            @bot\send_message msg.chat.id, 'no info'
        else
            response = table.concat [tostring e for e in *history], '\n'
            @bot\send_message msg.chat.id, response



:WhoDatBot, :extract_users
