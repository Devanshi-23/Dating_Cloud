import { fail, ok } from './http.js';
import { createId } from './store.js';

const reportStatuses = new Set(['IN_REVIEW', 'ACTIONED', 'DISMISSED']);
const memberStatuses = new Set(['ACTIVE', 'WARNED', 'SUSPENDED', 'BANNED']);
const rank = { MEMBER: 0, MODERATOR: 1, ADMIN: 2 };

export function registerAdmin(router, { store, requireAuth, page, findPerson }) {
  function requireStaff(minimum) {
    return (req, res, next) =>
      requireAuth(req, res, () => {
        if ((rank[req.user.role] ?? 0) < rank[minimum]) {
          return fail(res, 'FORBIDDEN', 'You do not have access to this.');
        }
        return next();
      });
  }

  function audit(actor, action, targetId, extra = {}) {
    store.auditLogs.push({
      id: createId('aud'),
      actorId: actor.id,
      action,
      targetId,
      at: new Date().toISOString(),
      ...extra,
    });
  }

  function directory() {
    const people = new Map();
    for (const person of store.profiles.values()) people.set(person.id, person);
    for (const person of store.users.values()) people.set(person.id, person);
    return [...people.values()];
  }

  router.get('/admin/reports', requireStaff('MODERATOR'), (req, res) => {
    const status = req.query.status ? String(req.query.status) : '';
    const items = store.reports.filter((report) => !status || report.status === status);
    return ok(res, page(items, req.query));
  });

  router.patch('/admin/reports/:reportId', requireStaff('MODERATOR'), (req, res) => {
    const report = store.reports.find((item) => item.id === req.params.reportId);
    if (!report) return fail(res, 'NOT_FOUND', 'We could not find what you were looking for.');
    const status = req.body?.status;
    if (status != null && !reportStatuses.has(status)) {
      return fail(res, 'VALIDATION_ERROR', 'Please correct the highlighted fields.', [
        { field: 'status', reason: 'INVALID' },
      ]);
    }
    if (status) report.status = status;
    if (typeof req.body?.resolutionNote === 'string') {
      report.resolutionNote = req.body.resolutionNote.trim();
    }
    if (req.body?.assignToMe === true) report.assigneeId = req.user.id;
    audit(req.user, 'REPORT_UPDATE', report.id, { status: report.status });
    return ok(res, {
      id: report.id,
      status: report.status,
      resolutionNote: report.resolutionNote ?? null,
      assigneeId: report.assigneeId ?? null,
    });
  });

  router.get('/admin/users', requireStaff('MODERATOR'), (req, res) => {
    const query = String(req.query.q || '').trim().toLowerCase();
    const status = req.query.status ? String(req.query.status) : '';
    const items = directory()
      .filter((person) => !status || (person.status || 'ACTIVE') === status)
      .filter((person) => {
        if (!query) return true;
        const haystack = [person.id, person.displayName, person.phoneNumber, person.email]
          .filter(Boolean)
          .join(' ')
          .toLowerCase();
        return haystack.includes(query);
      })
      .map((person) => ({
        id: person.id,
        displayName: person.displayName || '',
        phoneNumber: person.phoneNumber || null,
        email: person.email || null,
        status: person.status || 'ACTIVE',
        role: person.role || 'MEMBER',
      }));
    return ok(res, page(items, req.query));
  });

  router.patch('/admin/users/:userId/status', requireStaff('MODERATOR'), (req, res) => {
    const person = findPerson(req.params.userId);
    if (!person) return fail(res, 'NOT_FOUND', 'We could not find what you were looking for.');
    const status = req.body?.status;
    const reason = String(req.body?.reason || '').trim();
    if (!memberStatuses.has(status) || !reason) {
      return fail(res, 'VALIDATION_ERROR', 'Please correct the highlighted fields.', [
        { field: 'status', reason: 'INVALID' },
      ]);
    }
    if (status === 'BANNED' && req.user.role !== 'ADMIN') {
      return fail(res, 'FORBIDDEN', 'You do not have access to this.');
    }
    person.status = status;
    person.statusReason = reason;
    person.statusUntil = req.body?.until || null;
    audit(req.user, 'USER_STATUS', person.id, { status, reason });
    return ok(res, {
      id: person.id,
      status: person.status,
      statusReason: person.statusReason,
      statusUntil: person.statusUntil,
    });
  });

  router.get('/admin/audit-logs', requireStaff('ADMIN'), (req, res) => {
    const actorId = req.query.actorId ? String(req.query.actorId) : '';
    const targetId = req.query.targetId ? String(req.query.targetId) : '';
    const items = store.auditLogs.filter((entry) => {
      if (actorId && entry.actorId !== actorId) return false;
      if (targetId && entry.targetId !== targetId) return false;
      return true;
    });
    return ok(res, page(items, req.query));
  });
}
