local logger = require('separator.utils.logging')

---@alias node unknown
local ts_utils = require('nvim-treesitter.ts_utils')
local parsers = require("nvim-treesitter.parsers")

local M = {}

---Wrapper to get treesitter root parser
---@return node|nil
local function get_root()
    local parser = parsers.get_parser()
    if parser == nil then
        return nil
    end

    return parser:parse()[1]:root()
end

---Return node of "parent" that has given "named" as name in nested node
---@param parent node
---@param named string
---@return node|nil
local function get_named_node(parent, named)
    for node, name in parent:iter_children() do
        if name == named then
            return node
        end

        -- some languages have deeply nested structures
        -- in "declarator" parts can exist as well
        if name == "declarator" then
            local named_node = get_named_node(node, named)
            if named_node ~= nil then
                return named_node
            end

            -- when we are the furthest in the recursion and have an identifier, this can also be a function
            if node:type() == "identifier" then
                return node
            end

            return nil
        end
    end
end

---Return node of "parent" that has given "typed" as type in nested node
---@param parent node
---@param typed string
---@return node|nil
local function get_typed_node(parent, typed)
    for node, name in parent:iter_children() do
        if node:type() == typed then
            return node
        end

        -- some languages have deeply nested structures
        -- in "declarator" parts can exist as well
        if name == "declarator" then
            local typed_node = get_typed_node(node, typed)
            if typed_node ~= nil then
                return typed_node
            end

            return nil
        end
    end
end

---Get node information and construct a useable table out of it
---@param node node
---@return NodeInformation|nil
local function get_node_information(node)
    -- can be that some nodes have a not yet supported structure
    -- instead of crashing just ignore the node
    local function_name_node = get_named_node(node, "name")

    -- for example cpp has som edge cases where a "name" named node won't be found
    if function_name_node == nil then
        -- Operator overloads
        function_name_node = get_typed_node(node, "operator_name")
    end

    if function_name_node == nil then
        -- Reference return types
        local fd_node = get_typed_node(node, "function_declarator")
        function_name_node = get_named_node(fd_node, "identifier")
    end

    if function_name_node == nil then
        return nil
    end

    local function_name = vim.treesitter.get_node_text(function_name_node, 0)
    -- as fallback in case named node does not exist
    local line_content = vim.treesitter.get_node_text(node, 0)

    -- return line content in case we have no name (happens if there is no named node)
    function_name = function_name or line_content

    -- zero indexed
    -- local row, _, _ = node:start()
    local row, _, _ = node:end_()
    local line_number = row + 1

    ---@class NodeInformation
    ---@field line_number number
    ---@field function_name string
    return { line_number = line_number, function_name = function_name }
end

---Some languages (e.g. cpp) might want more information about the scope of a function
---request them of a node and use this to append the node information
---@param node any
---@return string|nil
local function get_scope_information_of_node(node)
    local class_scope_node = get_named_node(node, "scope")
    if class_scope_node ~= nil then
        local is_class_name = class_scope_node:type() == "namespace_identifier"
            or class_scope_node:type() == "template_type"

        if is_class_name then
            return vim.treesitter.get_node_text(class_scope_node, 0) .. "::"
        end
    end

    return nil
end

---Get all functions of the given "parent" node concatted into a table
---@param parent node
---@return NodeInformation[]
local function get_function_list_of_parent(parent)
    ---@type NodeInformation[]
    local content = {}

    if parent == nil then
        return content
    end

    for tsnode in parent:iter_children() do
        -- standard ways of declaring/defining functions
        local is_simple_function = tsnode:type() == "function_declaration"
            or tsnode:type() == "function_definition"
            or tsnode:type() == "local_function"
            or tsnode:type() == "method_definition"
            or tsnode:type() == "method_declaration"
            or tsnode:type() == "constructor_declaration"
            or tsnode:type() == "function_item"

        if is_simple_function then
            local info = get_node_information(tsnode)

            -- enhance function name with scope information
            local node_scope = get_scope_information_of_node(tsnode)
            if node_scope ~= nil and info ~= nil then
                info.function_name = node_scope .. info.function_name
            end
            table.insert(content, info)
        end

        -- some functions might have the information in their parent (assigned variables)
        local is_parent_dependend_function = tsnode:type() == "function_definition" or tsnode:type() == "arrow_function"

        if is_parent_dependend_function then
            -- we want to name of the variable that it was assigned to -> parent
            -- if it has valuable information
            local parent_has_information = tsnode:parent():type() == "variable_declarator"
                or tsnode:parent():type() == "variable_declaration"
                or tsnode:parent():type() == "assignment_statement"
                or tsnode:parent():type() == "expression_list"

            if parent_has_information then
                local info = get_node_information(tsnode:parent())
                table.insert(content, info)
            end
        end

        -- these structures might include functions (arrow function, variable as function, classes, etc)
        local is_simple_recursive_structure = tsnode:type() == "export_statement"
            or tsnode:type() == "variable_declarator"
            or tsnode:type() == "variable_declaration"
            or tsnode:type() == "lexical_declaration"
            or tsnode:type() == "template_declaration"
            or tsnode:type() == "preproc_ifdef"
            or tsnode:type() == "preproc_if"
            or tsnode:type() == "preproc_else"

        if is_simple_recursive_structure then
            local info = get_function_list_of_parent(tsnode)

            for _, node_information in ipairs(info) do
                table.insert(content, node_information)
            end
        end

        -- structure that most likely have multiple functions internally
        local is_complex_recursive_structure = tsnode:type() == "class_declaration"
            or tsnode:type() == "namespace_declaration"
            or tsnode:type() == "namespace_definition"
            or tsnode:type() == "impl_item"
            or tsnode:type() == "mod_item"

        if is_complex_recursive_structure then
            local structure_name_node = get_named_node(tsnode, "name")
            if structure_name_node == nil then
                structure_name_node = get_typed_node(tsnode, "type_identifier")
            end

            local structure_name = nil
            if structure_name_node ~= nil then
                structure_name = vim.treesitter.get_node_text(structure_name_node, 0)
            end

            -- body this might contain functions (methods)
            local body = get_named_node(tsnode, "body")
            local info = get_function_list_of_parent(body)

            local separator = " > "
            if tsnode:type() == "namespace_definition" or tsnode:type() == "impl_item" then
                separator = "::"
            end

            for _, node_information in ipairs(info) do
                -- append structure name infront of methods (or other structures)
                if structure_name ~= nil then
                    node_information.function_name = structure_name .. separator .. node_information.function_name
                end

                table.insert(content, node_information)
            end
        end
    end

    return content
end

---Global endpoint to get all functions of the current buffer
---structured into a table of multiple table informations
---@return NodeInformation[]
function M.get_current_functions()
    local root = get_root()
    if root == nil then
        logger.log("No Tressitter-parser found in the current buffer")
        return {}
    end

    local ok, content = pcall(get_function_list_of_parent, root)
    if not ok then
        logger.log("Something went wrong in the current buffer")
        logger.log("Current buffer might have unsuported language or syntax")
        return {}
    end

    -- sort content, it could have different order in some edge cases
    table.sort(content, function(a, b)
        return a.line_number < b.line_number
    end)

    return content
end

--- Find a list of functions, return the list or pass it to callback
--- @callback User function to handle the list of functions
function M.get_function_list(callback, config)
    local func_list = {}
    local result = M.get_current_functions()
    for _, node_info in ipairs(result) do
        table.insert(func_list, {
            type = "func",
            row = node_info.line_number,
            func_name = node_info.function_name
        })
    end
    if callback ~= nil then
        callback(func_list)
    end
    return func_list
end

return M
