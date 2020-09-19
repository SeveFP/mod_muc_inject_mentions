# Introduction

This module intercepts messages sent to a MUC, looks in the message's body if a user was mentioned and injects a mention type reference to that user implementing [XEP-0372](https://xmpp.org/extensions/xep-0372.html#usecase_mention)

## Features

1. Multiple mentions in the same message using affixes, including multiple mentions to the same user.
   Examples:  
   `Hello nickname`  
   `@nickname hey!`  
   `nickname, hi :)`  
   `Are you sure @nickname?`  

2. Mentions are only injected if no mention was found in a message, avoiding this way, injecting mentions in messages sent from clients with mentions support.

3. Configuration settings for customizing affixes and enabling/disabling the module for specific rooms.


# Configuring

## Enabling

```{.lua}

Component "rooms.example.net" "muc"

modules_enabled = {
    "muc_inject_mentions";
}

```

## Settings

Apart from just writing the nick of an occupant to trigger this module,
common affixes used when mentioning someone can be configured in Prosody's config file.  
Recommended affixes:

```
muc_inject_mentions_prefixes = {"@"} -- Example: @bob hello!
muc_inject_mentions_suffixes = {":", ",", "!", ".", "?"} -- Example: bob! How are you doing?
```

This module can be enabled/disabled for specific rooms.
Only one of the following settings must be set.

```
-- muc_inject_mentions_enabled_rooms = {"room@conferences.server.com"}
-- muc_inject_mentions_disabled_rooms = {"room@conferences.server.com"}
```

If none or both are found, all rooms in the muc component will have mentions enabled.

# Example stanzas

Alice sends the following message

```
<message id="af6ca" to="room@conference.localhost" type="groupchat">
    <body>@bob hey! Are you there?</body>
</message>
```

Then, the module detects `@bob` is a mention to `bob` and injects a mention type reference to him

```
<message from="room@conference.localhost/alice" id="af6ca" to="alice@localhost/ThinkPad" type="groupchat">
    <body>@bob hey! Are you there?</body>
    <reference xmlns="urn:xmpp:reference:0"
        begin="1"
        end="3"
        uri="xmpp:bob@localhost"
        type="mention"
    />
</message>
```
