import time
import uuid
from contextlib import contextmanager
from dataclasses import asdict, dataclass, field
from typing import Any

from multiagent.contracts import utc_now


@dataclass
class AgentEvent:
    event_id: str
    interaction_id: str
    event_type: str
    source: str
    target: str | None
    status: str
    created_at: str
    duration_ms: float | None = None
    payload: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


class EventTracer:
    def __init__(self, interaction_id: str):
        self.interaction_id = interaction_id
        self.events: list[AgentEvent] = []

    def emit(
        self,
        event_type: str,
        source: str,
        *,
        target: str | None = None,
        status: str = "completed",
        duration_ms: float | None = None,
        payload: dict[str, Any] | None = None,
    ) -> AgentEvent:
        event = AgentEvent(
            event_id=str(uuid.uuid4()),
            interaction_id=self.interaction_id,
            event_type=event_type,
            source=source,
            target=target,
            status=status,
            created_at=utc_now(),
            duration_ms=duration_ms,
            payload=payload or {},
        )
        self.events.append(event)
        return event

    @contextmanager
    def operation(self, event_type: str, source: str, *, target: str | None = None):
        started = time.perf_counter()
        try:
            yield
        except Exception as error:
            self.emit(
                event_type,
                source,
                target=target,
                status="failed",
                duration_ms=round((time.perf_counter() - started) * 1000, 3),
                payload={"error_type": type(error).__name__},
            )
            raise
        else:
            self.emit(
                event_type,
                source,
                target=target,
                duration_ms=round((time.perf_counter() - started) * 1000, 3),
            )

    def summary(self) -> list[dict[str, Any]]:
        return [
            {
                "event_type": event.event_type,
                "source": event.source,
                "target": event.target,
                "status": event.status,
                "duration_ms": event.duration_ms,
            }
            for event in self.events
        ]
