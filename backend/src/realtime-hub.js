const onlineUsers = new Set();

export function setUserOnline(userId, online) {
  if (!userId) return;
  if (online) onlineUsers.add(userId);
  else onlineUsers.delete(userId);
}

export function isUserOnline(userId) {
  return onlineUsers.has(userId);
}

let sink = () => {};

export function setRealtimeSink(next) {
  sink = next;
}

export function emitToUsers(userIds, event, payload) {
  for (const userId of new Set(userIds.filter(Boolean))) {
    sink(userId, event, payload);
  }
}
