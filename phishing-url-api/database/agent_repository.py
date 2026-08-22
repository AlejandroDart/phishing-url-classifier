import logging
import threading
from typing import Any

from psycopg2.extras import Json, RealDictCursor

from database.db import get_connection, release_connection
from multiagent.contracts import ConversationContext
from multiagent.events import AgentEvent


logger = logging.getLogger(__name__)


SCHEMA_SQL = """
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
"""


def _json_safe(value: Any) -> Any:
    if isinstance(value, dict):
        return {str(key): _json_safe(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_json_safe(item) for item in value]
    if hasattr(value, "item"):
        return value.item()
    return value


class AgentRepository:
    """Best-effort PostgreSQL history; chat remains available if storage fails."""

    def __init__(self):
        self._schema_ready = False
        self._schema_lock = threading.Lock()

    def _execute(self, callback):
        connection = None
        try:
            connection = get_connection()
            result = callback(connection)
            connection.commit()
            return result
        except Exception as error:
            if connection is not None:
                connection.rollback()
            logger.warning("Agent persistence unavailable: %s", error)
            return None
        finally:
            if connection is not None:
                release_connection(connection)

    def ensure_schema(self) -> bool:
        if self._schema_ready:
            return True
        with self._schema_lock:
            if self._schema_ready:
                return True

            def create(connection):
                with connection.cursor() as cursor:
                    cursor.execute(SCHEMA_SQL)
                return True

            self._schema_ready = bool(self._execute(create))
        return self._schema_ready

    def save_interaction(
        self,
        *,
        interaction_id: str,
        conversation_id: str,
        intent: str,
        user_message: str,
        status: str,
        analysis: dict[str, Any] | None,
        decision: dict[str, Any] | None,
        response_summary: str,
        events: list[AgentEvent],
    ) -> bool:
        if not self.ensure_schema():
            return False

        def save(connection):
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO agent_interactions (
                        interaction_id, conversation_id, intent, user_message,
                        status, analysis, decision, response_summary
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (interaction_id) DO NOTHING
                    """,
                    (
                        interaction_id,
                        conversation_id,
                        intent,
                        user_message,
                        status,
                        Json(_json_safe(analysis)) if analysis else None,
                        Json(_json_safe(decision)) if decision else None,
                        response_summary[:1000],
                    ),
                )
                for event in events:
                    cursor.execute(
                        """
                        INSERT INTO agent_events (
                            event_id, interaction_id, event_type, source, target,
                            status, duration_ms, payload, created_at
                        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                        ON CONFLICT (event_id) DO NOTHING
                        """,
                        (
                            event.event_id,
                            event.interaction_id,
                            event.event_type,
                            event.source,
                            event.target,
                            event.status,
                            event.duration_ms,
                            Json(_json_safe(event.payload)),
                            event.created_at,
                        ),
                    )
            return True

        return bool(self._execute(save))

    def latest_context(self, conversation_id: str) -> ConversationContext | None:
        if not self.ensure_schema():
            return None

        def fetch(connection):
            with connection.cursor(cursor_factory=RealDictCursor) as cursor:
                cursor.execute(
                    """
                    SELECT interaction_id, conversation_id, analysis, decision, created_at
                    FROM agent_interactions
                    WHERE conversation_id = %s
                      AND analysis IS NOT NULL
                      AND decision IS NOT NULL
                      AND status = 'completed'
                    ORDER BY created_at DESC
                    LIMIT 1
                    """,
                    (conversation_id,),
                )
                return cursor.fetchone()

        row = self._execute(fetch)
        if not row:
            return None
        return ConversationContext.from_dict({
            "conversation_id": row["conversation_id"],
            "interaction_id": str(row["interaction_id"]),
            "analysis": row["analysis"],
            "decision": row["decision"],
            "updated_at": row["created_at"].isoformat(),
        })


agent_repository = AgentRepository()
