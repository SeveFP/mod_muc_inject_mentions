module:depends("muc");

local jid_resource = require "util.jid".resource;

local prefixes = module:get_option("muc_inject_mentions_prefixes", nil)
local suffixes = module:get_option("muc_inject_mentions_suffixes", nil)
local enabled_rooms = module:get_option("muc_inject_mentions_enabled_rooms", nil)
local disabled_rooms = module:get_option("muc_inject_mentions_disabled_rooms", nil)

local reference_xmlns = "urn:xmpp:reference:0"

local function is_room_eligible(jid)
    if not enabled_rooms and not disabled_rooms then
        return true;
    end

    if enabled_rooms and not disabled_rooms then
        for _, _jid in ipairs(enabled_rooms) do
            if _jid == jid then
                return true
            end
        end
        return false
    end

    if disabled_rooms and not enabled_rooms then
        for _, _jid in ipairs(disabled_rooms) do
            if _jid == jid then
                return false
            end
        end
        return true
    end

    return true
end

local function has_nick_prefix(body, first)
    -- There is no prefix
    -- but mention could still be valid
    if first == 1 then return true end

    -- There are no configured prefixes
    if not prefixes or #prefixes < 1 then return false end

    -- Preffix must have a space before it,
    -- be the first character of the body
    -- or be the first character after a new line
    if body:sub(first - 2, first - 2) ~= "" and
        body:sub(first - 2, first - 2) ~= " " and
        body:sub(first - 2, first - 2) ~= "\n"
    then
        return false
    end

    local preffix = body:sub(first - 1, first - 1)
    for _, _preffix in ipairs(prefixes) do
        if preffix == _preffix then
            return true
        end
    end

    return false
end

local function has_nick_suffix(body, last)
    -- There is no suffix
    -- but mention could still be valid
    if last == #body then return true end

    -- There are no configured suffixes
    if not suffixes or #suffixes < 1 then return false end

    -- Suffix must have a space after it,
    -- be the last character of the body
    -- or be the last character before a new line
    if body:sub(last + 2, last + 2) ~= "" and
        body:sub(last + 2, last + 2) ~= " " and
        body:sub(last + 2, last + 2) ~= "\n"
    then
        return false
    end

    local suffix = body:sub(last+1, last+1)
    for _, _suffix in ipairs(suffixes) do
        if suffix == _suffix then
            return true
        end
    end

    return false
end

local function search_mentions(room, stanza)
    local body = stanza:get_child("body"):get_text();
    local mentions = {}

    for _, occupant in pairs(room._occupants) do
        local nick = jid_resource(occupant.nick);
        -- Check for multiple mentions to the same nickname in a message
        -- Hey @nick remember to... Ah, also @nick please let me know if...
        local matches = {}
        local _first
        local _last = 0
        while true do
            -- Use plain search as nick could contain
            -- characters used in Lua patterns
            _first, _last = body:find(nick, _last + 1, true)
            if _first == nil then break end
            table.insert(matches, {first=_first, last=_last})
        end

        -- Filter out intentional mentions from unintentional ones
        for _, match in ipairs(matches) do
            local bare_jid = occupant.bare_jid
            local first, last = match.first, match.last

            -- Body only contains nickname
            if first == 1 and last == #body then
                table.insert(mentions, {bare_jid=bare_jid, first=first, last=last})

            -- Nickname between spaces or new lines
            elseif body:sub(first - 1, first - 1) == " " or body:sub(first - 1, first - 1) == "\n" and
                body:sub(last + 1, last + 1) == " " or body:sub(last + 1, last + 1) == "\n"
            then
                table.insert(mentions, {bare_jid=bare_jid, first=first, last=last})
            else
                -- Check if occupant is mentioned using affixes
                local has_preffix = has_nick_prefix(body, first)
                local has_suffix = has_nick_suffix(body, last)

                -- @nickname: ...
                if has_preffix and has_suffix then
                    table.insert(mentions, {bare_jid=bare_jid, first=first, last=last})

                -- @nickname ...
                elseif has_preffix and not has_suffix then
                    if body:sub(last + 1, last + 1) == " " or
                        body:sub(last + 1, last + 1) == "\n"
                    then
                        table.insert(mentions, {bare_jid=bare_jid, first=first, last=last})
                    end

                -- nickname: ...
                elseif not has_preffix and has_suffix then
                    if body:sub(first - 1, first - 1) == " " or
                        body:sub(first - 1, first - 1) == "\n"
                    then
                        table.insert(mentions, {bare_jid=bare_jid, first=first, last=last})
                    end
                end
            end
        end
    end

    return mentions
end

local function muc_inject_mentions(event)
    local room, stanza = event.room, event.stanza;
    -- Inject mentions only if the room is configured for them
    if not is_room_eligible(room.jid) then return; end
    -- Only act on messages that do not include references.
    -- If references are found, it is assumed the client has mentions support
    if stanza:get_child("reference", reference_xmlns) then return; end

    local mentions = search_mentions(room, stanza)
    for _, mention in ipairs(mentions) do
        -- https://xmpp.org/extensions/xep-0372.html#usecase_mention
        stanza:tag(
            "reference", {
                xmlns=reference_xmlns,
                begin=tostring(mention.first - 1), -- count starts at 0
                ["end"]=tostring(mention.last - 1),
                type="mention",
                uri="xmpp:" .. mention.bare_jid,
            }
        ):up()
    end
end

module:hook("muc-occupant-groupchat", muc_inject_mentions)