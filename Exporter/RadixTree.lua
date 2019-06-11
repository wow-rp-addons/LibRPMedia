#!/usr/bin/env lua

-- Upvalues.
local min = math.min;
local strbyte = string.byte;
local strsub = string.sub;
local type = type;

-- Local declarations.
local GetCommonPrefixLength;

--- Radix tree module.
--  This module implements operations for a radix tree, with a few limitations
--  that match the scope of our usage.
--
--  The key limitation is that values inserted into the tree may only be
--  scalar values (not tables!).
local RadixTree = {};

--- Inserts the given key/value pair into a tree. If the exact key already
--  exists, its value is replaced.
--
--  The value can be any data type except a table.
function RadixTree.Insert(tree, key, value)
    assert(type(value) ~= "table", "value must not be a table");
    local keyLength = #key;

    local node;
    local nextNode = tree;
    repeat
        node, nextNode = nextNode, nil;

        for edgeIndex = 1, #node, 2 do
            local edgeLabel = node[edgeIndex];
            local edgeLabelLength = #edgeLabel;
            local sharedLength = GetCommonPrefixLength(key, edgeLabel);

            if sharedLength == edgeLabelLength then
                -- Exact match for this label.
                local edgeValue = node[edgeIndex + 1];
                if type(edgeValue) == "table" then
                    -- Exact match on label, points to a child. Recurse.
                    nextNode = edgeValue;
                    key = strsub(key, sharedLength + 1);
                    keyLength = keyLength - sharedLength;
                    break;
                elseif sharedLength == keyLength then
                    -- Exact match on key and label, points to a value.
                    node[edgeIndex + 1] = value;
                    return;
                end

                -- Allow falling through to the check below; this handles
                -- the case of inserting a key that is a superset of the
                -- current label (eg. label "Foo", key "FooBar").
            end

            if sharedLength > 0 then
                -- Partial match. Create a new node for the matched segments.
                local newNode = {};
                newNode[1] = strsub(edgeLabel, sharedLength + 1);
                newNode[2] = node[edgeIndex + 1];
                newNode[3] = strsub(key, sharedLength + 1);
                newNode[4] = value;

                -- Connect the current edge to the new node.
                node[edgeIndex] = strsub(key, 1, sharedLength);
                node[edgeIndex + 1] = newNode;
                return;
            end
        end
    until not nextNode

    -- If we get here, nothing is shared between anything present at
    -- this level of the tree, so it just needs a new edge.
    node[#node + 1] = key;
    node[#node + 1] = value;
end

--- Searches a tree for the given key, returning a value if an exact
--  match is located.
function RadixTree.FindExact(tree, key)
    local keyLength = #key;
    local nextNode = tree;
    local node;

    repeat
        node, nextNode = nextNode, nil;

        for edgeIndex = 1, #node, 2 do
            local edgeLabel = node[edgeIndex];
            local sharedLength = GetCommonPrefixLength(key, edgeLabel);

            if sharedLength == #edgeLabel then
                -- Exact match for this label.
                local edgeValue = node[edgeIndex + 1];
                if type(edgeValue) == "table" then
                    -- Exact match on label, points to a child. Recurse.
                    nextNode = edgeValue;
                    key = strsub(key, sharedLength + 1);
                    keyLength = keyLength - sharedLength;
                    break;
                elseif sharedLength == keyLength then
                    -- Exact match on key and label, points to a value.
                    return edgeValue;
                end
            end
        end
    until not nextNode

    return nil;
end

--- Internal API
--  The below declarations are for internal use only.

--- Returns the length of the common prefix shared by two strings. Returns
--  0 if no common prefix is shared.
function GetCommonPrefixLength(a, b)
    if a == b then
        return #a;
    end

    local offset = 1;
    local length = min(#a, #b);

    -- The innards of the loop are manually unrolled so we can minimize calls.
    while offset <= length do
        local a1, a2, a3, a4, a5, a6, a7, a8 = strbyte(a, offset, offset + 7);
        local b1, b2, b3, b4, b5, b6, b7, b8 = strbyte(b, offset, offset + 7);

        if a1 ~= b1 then
            return offset - 1;
        elseif a2 ~= b2 then
            return offset;
        elseif a3 ~= b3 then
            return offset + 1;
        elseif a4 ~= b4 then
            return offset + 2;
        elseif a5 ~= b5 then
            return offset + 3;
        elseif a6 ~= b6 then
            return offset + 4;
        elseif a7 ~= b7 then
            return offset + 5;
        elseif a8 ~= b8 then
            return offset + 6;
        end

        offset = offset + 8;
    end

    return offset - 1;
end

-- Module exports.
return RadixTree;
