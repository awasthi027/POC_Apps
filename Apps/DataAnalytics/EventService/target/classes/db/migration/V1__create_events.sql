CREATE TABLE events (
    id             BIGSERIAL PRIMARY KEY,
    project_id     TEXT        NOT NULL,
    event_id       TEXT        NOT NULL,      -- created by the SDK, the same on every retry
    event_name     TEXT        NOT NULL,
    event_time     TIMESTAMPTZ NOT NULL,      -- when it happened on the device
    received_at    TIMESTAMPTZ NOT NULL,      -- when the service accepted it
    session_id     TEXT,
    anonymous_id   TEXT,
    user_id        TEXT,
    properties     JSONB       NOT NULL DEFAULT '{}'::jsonb,
    context        JSONB       NOT NULL DEFAULT '{}'::jsonb,
    schema_version INTEGER,

    -- This is what makes retries safe: the same event can be inserted again and nothing changes.
    CONSTRAINT events_project_event_unique UNIQUE (project_id, event_id)
);

CREATE INDEX idx_events_project_time      ON events (project_id, event_time);
CREATE INDEX idx_events_project_name_time ON events (project_id, event_name, event_time);
