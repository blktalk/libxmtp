CREATE TABLE groups (
    -- Random ID generated by group creator
    "id" BLOB PRIMARY KEY NOT NULL,
    -- Based on the timestamp of the welcome message
    "created_at_ns" BIGINT NOT NULL,
    -- Enum of GROUP_MEMBERSHIP_STATE
    "membership_state" INT NOT NULL,
    -- Last time the installations were checked for the purpose of seeing if any are missing
    "installation_list_last_checked" BIGINT NOT NULL
);

-- Allow for efficient sorting of groups
CREATE INDEX groups_created_at_idx ON groups(created_at_ns);

CREATE INDEX groups_membership_state ON groups(membership_state);

-- Successfully processed messages meant to be returned to the user
CREATE TABLE group_messages (
    -- Derived via SHA256(CONCAT(decrypted_message_bytes, conversation_id, timestamp))
    "id" BLOB PRIMARY KEY NOT NULL,
    "group_id" BLOB NOT NULL,
    -- Message contents after decryption
    "decrypted_message_bytes" BLOB NOT NULL,
    -- Based on the timestamp of the message
    "sent_at_ns" BIGINT NOT NULL,
    -- Enum GROUP_MESSAGE_KIND
    "kind" INT NOT NULL,
    -- Could remove this if we added a table mapping installation_ids to wallet addresses
    "sender_installation_id" BLOB NOT NULL,
    "sender_account_address" TEXT NOT NULL,
    FOREIGN KEY (group_id) REFERENCES groups(id)
);

CREATE INDEX group_messages_group_id_sort_idx ON group_messages(group_id, sent_at_ns);

-- Used to keep track of the last seen message timestamp in a topic
CREATE TABLE refresh_state (
    "entity_id" BLOB NOT NULL,
    "entity_kind" INTEGER NOT NULL, -- Need to allow for groups and welcomes to be separated, since a malicious client could manipulate their group ID to match someone's installation_id and make a mess
    "cursor" BIGINT NOT NULL,

    PRIMARY KEY (entity_id, entity_kind)
);

-- This table is required to retry messages that do not send successfully due to epoch conflicts
CREATE TABLE group_intents (
    -- Serial ID auto-generated by the DB
    "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    -- Enum INTENT_KIND
    "kind" INT NOT NULL,
    "group_id" BLOB NOT NULL,
    -- Some sort of serializable blob that can be used to re-try the message if the first attempt failed due to conflict
    "data" BLOB NOT NULL,
    -- INTENT_STATE,
    "state" INT NOT NULL,
    -- The hash of the encrypted, concrete, form of the message if it was published.
    "payload_hash" BLOB UNIQUE,
    -- (Optional) data needed for the post-commit flow. For example, welcome messages
    "post_commit_data" BLOB,
    -- The number of publish attempts
    "publish_attempts" INT NOT NULL DEFAULT 0,
    
    FOREIGN KEY (group_id) REFERENCES groups(id)
);

CREATE INDEX group_intents_group_id_state ON group_intents(group_id, state);
