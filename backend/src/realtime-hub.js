let sink = () => {};

export function setRealtimeSink(next) {
  sink = next;
}

export function emitToUsers(userIds, event, payload) {
  for (const userId of new Set(userIds.filter(Boolean))) {
    sink(userId, event, payload);
  }
}
