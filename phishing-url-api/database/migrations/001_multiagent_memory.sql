CREATE TABLE IF NOT EXISTS agent_interactions (
    interaction_id UUID PRIMARY KEY,
    conversation_id VARCHAR(128) NOT NULL,
    intent VARCHAR(40) NOT NULL,
    user_message TEXT NOT NULL,
    status VARCHAR(24) NOT NULL,
    analysis JSONB,
    decision JSONB,
    response_summary TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_agent_interactions_conversation
    ON agent_interactions (conversation_id, created_at DESC);

CREATE TABLE IF NOT EXISTS agent_events (
    event_id UUID PRIMARY KEY,
    interaction_id UUID NOT NULL REFERENCES agent_interactions(interaction_id)
        ON DELETE CASCADE,
    event_type VARCHAR(80) NOT NULL,
    source VARCHAR(80) NOT NULL,
    target VARCHAR(80),
    status VARCHAR(24) NOT NULL,
    duration_ms DOUBLE PRECISION,
    payload JSONB,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_agent_events_interaction
    ON agent_events (interaction_id, created_at);
