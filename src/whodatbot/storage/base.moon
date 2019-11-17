_seq_qualname = (space_name, seq_name) -> '%s__%s__seq'\format(space_name, seq_name)

_copy_options = (options) ->
    if not options
        return {}
    return {k, v for k, v in pairs options}

_fix_index_options = (space_name, index_options) ->
    index_options = _copy_options index_options
    sequence = index_options.sequence
    if sequence
        index_options.sequence = _seq_qualname space_name, sequence
    return index_options


atomic = (fn) ->
    return (...) ->
        in_txn = box.is_in_txn!
        local savepoint
        if not in_txn
            box.begin!
        else
            savepoint = box.savepoint!
        ok, res, err = pcall fn, ...
        if ok and res
            if not in_txn
                box.commit!
        elseif in_txn
            box.rollback_to_savepoint savepoint
        else
            box.rollback!
        return res, err


class Storage

    -- name
    -- option
    -- fields
    -- indexes
    -- sequences

    new: (recreate=false) =>
        space_name = @name
        space = box.space[space_name]
        if space
            if not recreate
                @space = space
                return
            space\drop!

        options = _copy_options @options
        if not options.field_count
            options.field_count = #@fields
        space = box.schema.space.create space_name, options

        space\format @fields

        if @sequences
            for seq_name, seq_options in pairs @sequences
                seq_name = _seq_qualname space_name, seq_name
                seq_options = _copy_options seq_options
                seq_options.if_not_exists = true
                box.schema.sequence.create seq_name, seq_options

        primary_idx_options = @indexes.primary
        assert primary_idx_options, 'no primary index'
        primary_idx_options = _fix_index_options space_name, primary_idx_options
        space\create_index 'primary', primary_idx_options
        for idx_name, idx_options in pairs @indexes
            if idx_name ~= 'primary'
                idx_options = _fix_index_options space_name, idx_options
                space\create_index idx_name, idx_options

        @space = space


:Storage, :atomic
