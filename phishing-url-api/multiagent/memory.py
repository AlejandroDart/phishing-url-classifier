import threading
import time
from collections import OrderedDict

from multiagent.contracts import ConversationContext


class ShortTermMemory:
    def __init__(self, ttl_seconds: int = 7200, max_conversations: int = 500):
        self.ttl_seconds = ttl_seconds
        self.max_conversations = max_conversations
        self._items: OrderedDict[str, tuple[float, ConversationContext]] = OrderedDict()
        self._lock = threading.RLock()

    def put(self, context: ConversationContext) -> None:
        with self._lock:
            self._purge_expired()
            self._items.pop(context.conversation_id, None)
            self._items[context.conversation_id] = (time.monotonic(), context)
            while len(self._items) > self.max_conversations:
                self._items.popitem(last=False)

    def get(self, conversation_id: str) -> ConversationContext | None:
        with self._lock:
            self._purge_expired()
            item = self._items.pop(conversation_id, None)
            if item is None:
                return None
            _, context = item
            self._items[conversation_id] = (time.monotonic(), context)
            return context

    def clear(self, conversation_id: str) -> None:
        with self._lock:
            self._items.pop(conversation_id, None)

    def _purge_expired(self) -> None:
        cutoff = time.monotonic() - self.ttl_seconds
        expired = [key for key, (created, _) in self._items.items() if created < cutoff]
        for key in expired:
            self._items.pop(key, None)


short_term_memory = ShortTermMemory()
