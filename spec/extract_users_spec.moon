import extract_users from require 'whodatbot.bot'


table_sort = table.sort

sort_func = (first, second) -> first.id < second.id
sort_users = (users) -> table_sort users, sort_func


tests = {
    -- #1
    {
        {}
        {}
    }
    -- #2
    {
        {
            message_id: 2
            date: 1573660000
            text: '/start'
            from: {is_bot: false, first_name: 'John', id: 123}
            chat: {type: 'private', first_name: 'John', id: 123}
            entities: {{type: 'bot_command', length: 5, offset: 0}}
        }

        {
            {first_name: 'John', id: 123}
        }
    }
    -- #3
    {
        {
            message_id: 3
            date: 1573660000
            text: '/start'
            from: {is_bot: false, first_name: 'John', last_name: 'Smith', id: 123}
            chat: {type: 'supergroup', title: 'group name', id: -456}
            text: 'Hi!'
        }

        {
            {first_name: 'John', last_name: 'Smith', id: 123}
        }
    }
    -- #4
    {
        {
            message_id: 4
            forward_date: 1573660000
            date: 1573660005
            from: {is_bot: false, first_name: 'John', id: 123}
            chat: {type: 'private', first_name: 'John', id: 123}
            forward_from: {is_bot: false, username: 'pak01', first_name: 'Peter', id: 45}
            text: 'test'
        }

        {
            {first_name: 'Peter', username: 'pak01', id: 45}
            {first_name: 'John', id: 123}
        }
    }
    -- #5
    {
        {
            message_id: 5
            forward_date: 1573660000
            date: 1573660005
            from: {is_bot: false, first_name: 'John', id: 123}
            chat: {type: 'private', first_name: 'John', id: 123}
            forward_from: {is_bot: true, username: 'tinystash_bot', first_name: 'tiny[stash]', id: 419864769}
            text: 'test'
        }

        {
            {first_name: 'John', id: 123}
        }
    }
    -- #6
    {
        {
            message_id: 6
            date: 1573660005
            from: {is_bot: false, first_name: 'John', id: 123}
            chat: {type: 'supergroup', title: 'group name', id: -456}
            reply_to_message: {
                message_id: 3
                date: 1573660000
                from: {is_bot: false, username: 'pak01', first_name: 'Peter', id: 45}
                chat: {type: 'supergroup', title: 'group name', id: -456}
                text: 'ping'

            }
            text: 'pong'
        }

        {
            {first_name: 'Peter', username: 'pak01', id: 45}
            {first_name: 'John', id: 123}
        }
    }
    -- #7
    {
        {
            message_id: 7
            date: 1573660005
            from: {is_bot: false, first_name: 'John', id: 123}
            chat: {type: 'supergroup', title: 'group name', id: -456}
            left_chat_member: {is_bot: false, username: 'pak01', first_name: 'Peter', id: 45}
            left_chat_participant: {is_bot: false, username: 'pak01', first_name: 'Peter', id: 45}
        }

        {
            {first_name: 'Peter', username: 'pak01', id: 45}
            {first_name: 'John', id: 123}
        }
    }
    -- #8
    {
        {
            message_id: 8
            date: 1573660005
            from: {is_bot: false, first_name: 'John', id: 123}
            chat: {type: 'supergroup', title: 'group name', id: -456}
            new_chat_member: {is_bot: false, username: 'pak01', first_name: 'Peter', id: 45}
            new_chat_members: {
                {is_bot: false, username: 'asdf', first_name: 'Roger', last_name: 'Smith', id: 67}
                {is_bot: false, username: 'pak01', first_name: 'Peter', id: 45}
            }
        }

        {
            {first_name: 'Peter', username: 'pak01', id: 45}
            {username: 'asdf', first_name: 'Roger', last_name: 'Smith', id: 67}
            {first_name: 'John', id: 123}
        }
    }
}


describe 'extract_users', ->

    for idx, {msg, expected} in pairs tests
        it 'test #%d'\format(idx), ->
            extracted = extract_users msg
            sort_users extracted
            assert.are.same expected, extracted
