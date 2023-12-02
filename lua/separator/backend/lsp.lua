-- symbol kind definition, copied from
-- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/
-- export namespace SymbolKind {
--     export const File = 1;
--     export const Module = 2;
--     export const Namespace = 3;
--     export const Package = 4;
--     export const Class = 5;
--     export const Method = 6;
--     export const Property = 7;
--     export const Field = 8;
--     export const Constructor = 9;
--     export const Enum = 10;
--     export const Interface = 11;
--     export const Function = 12;
--     export const Variable = 13;
--     export const Constant = 14;
--     export const String = 15;
--     export const Number = 16;
--     export const Boolean = 17;
--     export const Array = 18;
--     export const Object = 19;
--     export const Key = 20;
--     export const Null = 21;
--     export const EnumMember = 22;
--     export const Struct = 23;
--     export const Event = 24;
--     export const Operator = 25;
--     export const TypeParameter = 26;
-- }

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------
local KINDS_TO_NAME = {
    "File",          -- 1
    "Module",        -- 2
    "Namespace",     -- 3
    "Package",       -- 4
    "Class",         -- 5
    "Method",        -- 6
    "Property",      -- 7
    "Field",         -- 8
    "Constructor",   -- 9
    "Enum",          -- 10
    "Interface",     -- 11
    "Function",      -- 12
    "Variable",      -- 13
    "Constant",      -- 14
    "String",        -- 15
    "Number",        -- 16
    "Boolean",       -- 17
    "Array",         -- 18
    "Object",        -- 19
    "Key",           -- 20
    "Null",          -- 21
    "EnumMember",    -- 22
    "Struct",        -- 23
    "Event",         -- 24
    "Operator",      -- 25
    "TypeParameter", -- 26
}

-- recursively proces for File (1), Module (2), Namespace (3), Package (4),
-- Class (5)
local RECURSIVE_KINDS = { 1, 2, 3, 4, 5 }
-- we want Class (5), Struct(23), Enum (10), Interface (11),
-- Method (6), Function (12), Constructor (9), operator(25)
local WANNABLE_KINDS = { 5, 6, 9, 10, 11, 12, 23, 25 }

local KINDS_TO_TYPE = {
    Class = "class",
    Struct = "class",
    Interface = "class",
    Enum = "class",
    Constructor = "method",
    Operator = "method",
    Method = "method",
    Function = "func",
}

-------------------------------------------------------------------------------
-- functions
-------------------------------------------------------------------------------

local logger = require('separator.utils.logging')

local M = {}


local function process_locations(location, callback)
    -- re-org symboles by types
    local symblesByType = {}
    for _, item in ipairs(location) do
        if symblesByType[item.kind] == nil then
            symblesByType[item.kind] = {}
        end
        table.insert(symblesByType[item.kind], item)
    end

    local return_list = {}
    for kind_name, type in pairs(KINDS_TO_TYPE) do
        if vim.tbl_contain(symblesByType, kind_name) then
            for _, item in ipairs(symblesByType[kind_name]) do
                local func_name = string.sub(item.text, string.len(kind_name) + 3)
                table.insert(return_list, {
                    type = type,
                    row = item.lnum,
                    name = func_name
                })
            end
        end
    end
    callback(return_list)
end


local function process_symbles(symbols)
    local function process_node(node)
        local result = {}
        -- if this node need to check children
        -- if vim.tbl_contains(RECURSIVE_KINDS, node.kind) then
        --     local inner = process_symbles(node.children)
        --     for _, v in ipairs(inner) do
        --         table.insert(result, v)
        --     end
        -- end
        -- if this node should be marked, add it
        if vim.tbl_contains(WANNABLE_KINDS, node.kind) then
            table.insert(result, {
                type = KINDS_TO_TYPE[KINDS_TO_NAME[node.kind]],
                row = node.range.start.line + 1, -- lsp lines starts from 0
                start_line = node.range.start.line + 1,
                end_line = node.range["end"].line + 1,
                name = node.name
            })
        end

        -- if has children, check childrens
        if symbols.children ~= nil then
            local inner_result = process_symbles(symbols.children)
            for _, v in ipairs(inner_result) do
                table.insert(result, v)
            end
        end

        return result
    end


    local return_list = {}

    -- only have 1 entry
    if symbols.kind ~= nil then
        logger.log('Separator.nvim: found a single node')
        return process_node(symbols)
    end

    if not vim.tbl_islist(symbols) then
        logger.log('------------------------------------------')
        logger.log('Separator.nvim: Found an invalid symbole. Neither a node or a list')
        logger.log_obj(symbols)
    end
    -- now this symbols should be an array
    logger.log('****************************************')
    -- logger.log_obj(symbols)
    for _, item in pairs(symbols) do
        -- logger.log('------------------------------------------')
        -- logger.log_obj(item)
        local inner_result = process_symbles(item)
        for _, v in ipairs(inner_result) do
            table.insert(return_list, v)
        end
        if symbols.children ~= nil then
            inner_result = process_symbles(symbols.children)
            for _, v in ipairs(inner_result) do
                table.insert(return_list, v)
            end
        end
    end


    logger.log('=================================')
    logger.log_obj(return_list)
    return return_list
end

function M.get_function_list(callback, config)
    local params = vim.lsp.util.make_position_params(0)
    local request_success = vim.lsp.buf_request(0, "textDocument/documentSymbol",
        params,
        function(err, symbols, _, _)
            logger.log_obj(symbols)
            local return_list = process_symbles(symbols)
            callback(return_list)
        end
    )
    logger.log('requrest success = ' .. tostring(request_success))
    logger.log_obj(request_success)
end

return M
