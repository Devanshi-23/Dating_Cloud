import express from 'express';
import jwt from 'jsonwebtoken';
import { config } from './config.js';
import { registerAdmin } from './admin-routes.js';
import { registerExtended } from './extended-routes.js';
import { fail, ok } from './http.js';
import { emitToUsers } from './realtime-hub.js';
import { blankMemberAccount, createId, createStore } from './store.js';

const imageTypes = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/heic']);
const mediaPurposes = new Set(['PROFILE_PHOTO', 'VERIFICATION_SELFIE', 'CHAT_ATTACHMENT']);

export const store = createStore();
const phonePattern = /^\+[1-9]\d{7,14}$/;
const allowedActions = new Set(['LIKE', 'PASS', 'SUPER_LIKE']);
const allowedShowMe = new Set(['WOMEN', 'MEN', 'EVERYONE']);
const allowedGoals = new Set([
  'LONG_TERM',
  'LONG_TERM_OPEN_TO_SHORT',
  'SHORT_TERM_OPEN_TO_LONG',
  'SHORT_TERM_FUN',
  'NEW_FRIENDS',
  'STILL_FIGURING_OUT',
]);
const allowedGenders = new Set(['WOMAN', 'MAN', 'NON_BINARY']);

function signAccess(userId) {
  const role = store.users.get(userId)?.role || 'MEMBER';
  return jwt.sign({ sub: userId, typ: 'access', role }, config.jwtAccessSecret, {
    expiresIn: config.accessTtl,
  });
}

function signRefresh(userId) {
  const token = jwt.sign(
    { sub: userId, typ: 'refresh', jti: createId('jti') },
    config.jwtRefreshSecret,
    { expiresIn: config.refreshTtl },
  );
  const decoded = jwt.decode(token);
  store.refreshTokens.set(token, { userId, exp: decoded.exp });
  return token;
}

function issueTokens(userId) {
  return {
    accessToken: signAccess(userId),
    refreshToken: signRefresh(userId),
  };
}

function requireAuth(req, res, next) {
  const header = req.get('authorization') || '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    return fail(res, 'UNAUTHENTICATED', 'Your session has expired. Please sign in.');
  }
  try {
    const payload = jwt.verify(match[1], config.jwtAccessSecret);
    if (payload.typ !== 'access' || !store.users.has(payload.sub)) {
      return fail(res, 'UNAUTHENTICATED', 'Your session has expired. Please sign in.');
    }
    req.user = store.users.get(payload.sub);
    return next();
  } catch {
    return fail(res, 'UNAUTHENTICATED', 'Your session has expired. Please sign in.');
  }
}

function photosOf(person) {
  if (Array.isArray(person.photos) && person.photos.length) {
    return person.photos.map((photo, order) => ({
      id: photo.id,
      url: photo.url,
      order,
    }));
  }
  return person.photoUrls.map((url, order) => ({
    id: `pho_${person.id}_${order}`,
    url,
    order,
  }));
}

function isBlocked(a, b) {
  return store.blocks.some(
    (item) =>
      (item.userId === a && item.blockedUserId === b) ||
      (item.userId === b && item.blockedUserId === a),
  );
}

function dropRelationship(a, b) {
  for (let index = store.matches.length - 1; index >= 0; index -= 1) {
    const item = store.matches[index];
    const pair = [item.userId, item.otherUserId];
    if (!pair.includes(a) || !pair.includes(b)) continue;
    const removed = { matchId: item.id, conversationId: item.conversationId };
    store.matches.splice(index, 1);
    store.conversations.delete(item.conversationId);
    for (let messageIndex = store.messages.length - 1; messageIndex >= 0; messageIndex -= 1) {
      if (store.messages[messageIndex].conversationId === item.conversationId) {
        store.messages.splice(messageIndex, 1);
      }
    }
    emitToUsers(pair, 'match:removed', removed);
  }
}

function pushNotice(userId, type, title, body, data) {
  const prefs = store.users.get(userId)?.notificationPreferences;
  if (type === 'NEW_MESSAGE' && prefs?.messages === false) return;
  if (type === 'NEW_MATCH' && prefs?.newMatches === false) return;
  store.notifications.unshift({
    id: createId('ntf'),
    userId,
    type,
    title,
    body,
    data,
    createdAt: new Date().toISOString(),
    readAt: null,
  });
}

export function participantConversation(userId, conversationId) {
  const conversation = store.conversations.get(conversationId);
  if (!conversation?.userIds.includes(userId)) return null;
  const otherId = conversation.userIds.find((id) => id !== userId);
  if (otherId && isBlocked(userId, otherId)) return null;
  return conversation;
}

export function markMessagesRead(userId, message) {
  const conversation = store.conversations.get(message.conversationId);
  if (!conversation?.userIds.includes(userId)) return false;
  for (const item of store.messages) {
    if (
      item.conversationId === conversation.id &&
      item.senderId !== userId &&
      item.sentAt <= message.sentAt
    ) {
      item.status = 'READ';
    }
  }
  emitToUsers(conversation.userIds, 'message:read', {
    conversationId: conversation.id,
    readerId: userId,
    upToMessageId: message.id,
    readAt: new Date().toISOString(),
  });
  return true;
}

function publicProfile(person, distanceKm = person.distanceKm ?? null) {
  return {
    id: person.id,
    displayName: person.displayName,
    age: person.age,
    bio: person.bio ?? '',
    interests: person.interests ?? [],
    photos: photosOf(person),
    city: person.city ?? '',
    occupation: person.occupation ?? null,
    distanceKm,
    isVerified: Boolean(person.isVerified),
    relationshipGoal: person.relationshipGoal ?? null,
    basics: person.basics ?? {},
    prompt: person.prompt ?? null,
  };
}

function myProfile(user) {
  return {
    ...publicProfile(user, null),
    phoneNumber: user.phoneNumber,
    onboardingComplete: user.onboardingComplete,
    preferences: user.preferences,
  };
}

function ageOn(dateOfBirth, today) {
  let age = today.getUTCFullYear() - dateOfBirth.getUTCFullYear();
  const hadBirthday =
    today.getUTCMonth() > dateOfBirth.getUTCMonth() ||
    (today.getUTCMonth() === dateOfBirth.getUTCMonth() &&
      today.getUTCDate() >= dateOfBirth.getUTCDate());
  if (!hadBirthday) age -= 1;
  return age;
}

function findPerson(id) {
  return store.users.get(id) || store.profiles.get(id) || null;
}

function page(items, query) {
  const limit = Math.min(Math.max(Number(query.limit) || 20, 1), 50);
  const start = query.cursor ? Number(query.cursor) : 0;
  const offset = Number.isFinite(start) ? start : 0;
  const slice = items.slice(offset, offset + limit);
  const next = offset + limit < items.length ? String(offset + limit) : null;
  return { items: slice, nextCursor: next };
}

function matchFor(record) {
  return {
    id: record.id,
    otherUser: publicProfile(findPerson(record.otherUserId)),
    matchedAt: record.matchedAt,
    conversationId: record.conversationId,
  };
}

function lastMessage(conversationId) {
  const found = store.messages.filter((message) => message.conversationId === conversationId);
  return found.length ? found[found.length - 1] : null;
}

function conversationJson(user, conversation) {
  const otherId = conversation.userIds.find((id) => id !== user.id);
  return {
    id: conversation.id,
    matchId: conversation.matchId,
    otherUser: publicProfile(findPerson(otherId)),
    lastMessage: lastMessage(conversation.id),
    unreadCount: store.messages.filter(
      (message) =>
        message.conversationId === conversation.id &&
        message.senderId !== user.id &&
        message.status !== 'READ',
    ).length,
  };
}

function userMatches(userId) {
  return store.matches.filter((item) => item.userId === userId || item.otherUserId === userId);
}

function remember(req, value) {
  const key = req.get('idempotency-key');
  if (key) store.idempotency.set(`${req.user.id}:${key}`, value);
  return value;
}

function replay(req, res) {
  const key = req.get('idempotency-key');
  if (!key) return null;
  const cached = store.idempotency.get(`${req.user.id}:${key}`);
  if (cached) ok(res, cached);
  return cached ?? null;
}

export function registerRoutes(app) {
  const router = express.Router();

  router.get('/health', (_req, res) => {
    ok(res, { status: 'ok' });
  });

  router.post('/auth/otp/request', (req, res) => {
    const phoneNumber = String(req.body?.phoneNumber || '').replace(/[\s\-()]/g, '');
    if (!phonePattern.test(phoneNumber)) {
      return fail(res, 'VALIDATION_ERROR', 'Please correct the highlighted fields.', [
        { field: 'phoneNumber', reason: 'E164' },
      ]);
    }
    const now = Date.now();
    const previous = store.challenges.get(phoneNumber);
    if (previous && now - previous.sentAt < config.otpResendSeconds * 1000) {
      return fail(res, 'RATE_LIMITED', 'Too many attempts. Please wait and try again.');
    }
    store.challenges.set(phoneNumber, {
      code: config.devOtpCode,
      sentAt: now,
      expiresAt: now + config.otpExpiresSeconds * 1000,
    });
    return ok(res, {
      expiresInSeconds: config.otpExpiresSeconds,
      resendAfterSeconds: config.otpResendSeconds,
    });
  });

  router.post('/auth/otp/verify', (req, res) => {
    const phoneNumber = String(req.body?.phoneNumber || '').replace(/[\s\-()]/g, '');
    const code = String(req.body?.code || '');
    const challenge = store.challenges.get(phoneNumber);
    if (!challenge || code === '000000') {
      return fail(res, 'OTP_EXPIRED', 'That code has expired. Request a new one.');
    }
    if (Date.now() > challenge.expiresAt) {
      store.challenges.delete(phoneNumber);
      return fail(res, 'OTP_EXPIRED', 'That code has expired. Request a new one.');
    }
    if (code !== challenge.code) {
      return fail(res, 'OTP_INVALID', 'That code is incorrect.');
    }
    store.challenges.delete(phoneNumber);

    let user = [...store.users.values()].find((member) => member.phoneNumber === phoneNumber);
    let isNewUser = false;
    if (!user && phoneNumber === config.demoPhone) {
      user = store.users.get(store.demoId);
      user.phoneNumber = phoneNumber;
    } else if (!user) {
      isNewUser = true;
      user = blankMemberAccount(createId('usr'), phoneNumber);
      store.users.set(user.id, user);
    }
    if (user.deletion) user.deletion = null;
    const staffRole = config.staffRoles.get(phoneNumber);
    if (staffRole) user.role = staffRole;
    if (user.status === 'BANNED') {
      return fail(res, 'ACCOUNT_INELIGIBLE', 'This account is not eligible.');
    }

    return ok(res, {
      isNewUser,
      user: { id: user.id, onboardingComplete: user.onboardingComplete },
      tokens: issueTokens(user.id),
    });
  });

  router.post('/auth/token/refresh', (req, res) => {
    const refreshToken = req.body?.refreshToken;
    const saved = typeof refreshToken === 'string' ? store.refreshTokens.get(refreshToken) : null;
    if (!saved) {
      return fail(res, 'UNAUTHENTICATED', 'Your session has expired. Please sign in.');
    }
    try {
      const payload = jwt.verify(refreshToken, config.jwtRefreshSecret);
      if (payload.typ !== 'refresh' || payload.sub !== saved.userId) {
        throw new Error('mismatch');
      }
    } catch {
      store.refreshTokens.delete(refreshToken);
      return fail(res, 'UNAUTHENTICATED', 'Your session has expired. Please sign in.');
    }
    store.refreshTokens.delete(refreshToken);
    const tokens = issueTokens(saved.userId);
    return ok(res, tokens);
  });

  router.post('/auth/logout', requireAuth, (req, res) => {
    const refreshToken = req.body?.refreshToken;
    if (typeof refreshToken === 'string') store.refreshTokens.delete(refreshToken);
    return ok(res, { loggedOut: true });
  });

  router.get('/interests', requireAuth, (_req, res) => {
    ok(res, { items: store.interests });
  });

  router.post('/media/upload-url', requireAuth, (req, res) => {
    const { purpose, contentType, sizeBytes } = req.body ?? {};
    const details = [];
    if (!mediaPurposes.has(purpose)) details.push({ field: 'purpose', reason: 'UNSUPPORTED' });
    if (!imageTypes.has(contentType)) {
      details.push({ field: 'contentType', reason: 'UNSUPPORTED_TYPE' });
    }
    if (!Number.isInteger(sizeBytes) || sizeBytes < 1 || sizeBytes > 10_485_760) {
      details.push({ field: 'sizeBytes', reason: 'TOO_LARGE' });
    }
    if (details.length) {
      return fail(res, 'VALIDATION_ERROR', 'Please correct the highlighted fields.', details);
    }
    const mediaId = createId('med');
    store.media.set(mediaId, {
      id: mediaId,
      ownerId: req.user.id,
      purpose,
      contentType,
      sizeBytes,
      bytes: null,
      status: 'PENDING',
    });
    const uploadUrl = `${req.protocol}://${req.get('host')}/api/v1/media/raw/${mediaId}`;
    return ok(
      res,
      {
        mediaId,
        uploadUrl,
        method: 'PUT',
        headers: { 'Content-Type': contentType },
        expiresAt: new Date(Date.now() + 15 * 60 * 1000).toISOString(),
      },
      201,
    );
  });

  router.put('/media/raw/:mediaId', express.raw({ type: '*/*', limit: '10mb' }), (req, res) => {
    const item = store.media.get(req.params.mediaId);
    if (!item) return fail(res, 'NOT_FOUND', 'We could not find what you were looking for.');
    const body = Buffer.isBuffer(req.body) ? req.body : Buffer.alloc(0);
    if (body.length < 1 || body.length > 8_000_000) {
      item.status = 'REJECTED';
      return fail(res, 'MEDIA_REJECTED', 'That photo can’t be used. Choose another one.', [
        { field: 'file', reason: 'TOO_LARGE' },
      ]);
    }
    item.bytes = body;
    item.status = 'READY';
    return res.status(200).end();
  });

  router.get('/media/files/:mediaId', (req, res) => {
    const item = store.media.get(req.params.mediaId);
    if (!item?.bytes || item.status !== 'READY') {
      return fail(res, 'NOT_FOUND', 'We could not find what you were looking for.');
    }
    res.set('Content-Type', item.contentType).send(item.bytes);
  });

  router.post('/media/complete', requireAuth, (req, res) => {
    const item = store.media.get(req.body?.mediaId);
    if (!item || item.ownerId !== req.user.id) {
      return fail(res, 'VALIDATION_ERROR', 'Please correct the highlighted fields.', [
        { field: 'mediaId', reason: 'UNKNOWN_MEDIA' },
      ]);
    }
    if (item.status !== 'READY') {
      return fail(res, 'MEDIA_REJECTED', 'That photo can’t be used. Choose another one.', [
        { field: 'mediaId', reason: 'NOT_READY' },
      ]);
    }
    const url = `${req.protocol}://${req.get('host')}/api/v1/media/files/${item.id}`;
    return ok(res, { mediaId: item.id, status: item.status, url });
  });

  router.post('/profile/onboarding', requireAuth, (req, res) => {
    const body = req.body ?? {};
    const catalogue = new Map(store.interests.map((item) => [item.id, item]));
    const interestIds = Array.isArray(body.interestIds) ? body.interestIds : [];
    const photoMediaIds = Array.isArray(body.photoMediaIds) ? body.photoMediaIds : [];
    const displayName = String(body.displayName || '').trim();
    const bio = String(body.bio || '').trim();
    const details = [];

    if (!displayName || displayName.length > 40) {
      details.push({ field: 'displayName', reason: 'LENGTH_1_40' });
    }
    if (
      interestIds.length < 1 ||
      interestIds.length > 10 ||
      !interestIds.every((id) => catalogue.has(id))
    ) {
      details.push({ field: 'interestIds', reason: 'COUNT_1_10' });
    }
    const photosReady = photoMediaIds.every((id) => {
      const item = store.media.get(id);
      return item && item.ownerId === req.user.id && item.status === 'READY';
    });
    if (
      photoMediaIds.length < 2 ||
      photoMediaIds.length > 6 ||
      new Set(photoMediaIds).size !== photoMediaIds.length ||
      !photosReady
    ) {
      details.push({ field: 'photoMediaIds', reason: 'COUNT_2_6' });
    }
    const distance = Number(body.maxDistanceKm);
    if (!Number.isInteger(distance) || distance < 1 || distance > 500) {
      details.push({ field: 'maxDistanceKm', reason: 'RANGE_1_500' });
    }
    if (bio.length > 500) details.push({ field: 'bio', reason: 'MAX_500' });
    if (!allowedShowMe.has(body.showMe)) details.push({ field: 'showMe', reason: 'INVALID' });
    if (!allowedGenders.has(body.gender)) details.push({ field: 'gender', reason: 'INVALID' });
    if (!allowedGoals.has(body.relationshipGoal)) {
      details.push({ field: 'relationshipGoal', reason: 'INVALID' });
    }
    if (body.acceptedTermsVersion !== config.termsVersion) {
      details.push({ field: 'acceptedTermsVersion', reason: 'NOT_CURRENT' });
    }
    const prompt = body.prompt;
    if (
      prompt != null &&
      (typeof prompt.promptId !== 'string' ||
        typeof prompt.answer !== 'string' ||
        !prompt.answer.trim() ||
        prompt.answer.trim().length > 150)
    ) {
      details.push({ field: 'prompt', reason: 'INVALID' });
    }
    if (details.length) {
      return fail(res, 'VALIDATION_ERROR', 'Please correct the highlighted fields.', details);
    }

    const dateOfBirth = new Date(`${body.dateOfBirth}T00:00:00.000Z`);
    if (Number.isNaN(dateOfBirth.getTime()) || ageOn(dateOfBirth, new Date()) < 18) {
      if (Number.isNaN(dateOfBirth.getTime())) {
        return fail(res, 'VALIDATION_ERROR', 'Please correct the highlighted fields.', [
          { field: 'dateOfBirth', reason: 'DATE' },
        ]);
      }
      return fail(res, 'ACCOUNT_INELIGIBLE', 'This account is not eligible.');
    }

    const user = req.user;
    user.displayName = displayName;
    user.dateOfBirth = body.dateOfBirth;
    user.age = ageOn(dateOfBirth, new Date());
    user.bio = bio;
    user.gender = body.gender;
    user.showGender = Boolean(body.showGender);
    user.relationshipGoal = body.relationshipGoal;
    user.interests = interestIds.map((id) => catalogue.get(id).label);
    user.photos = photoMediaIds.map((id) => ({
      id: `pho_${id}`,
      mediaId: id,
      url: `${req.protocol}://${req.get('host')}/api/v1/media/files/${id}`,
    }));
    user.photoUrls = user.photos.map((photo) => photo.url);
    user.city = body.location ? 'Pune' : '';
    user.basics = body.basics && typeof body.basics === 'object' ? body.basics : {};
    user.prompt = prompt ? { promptId: prompt.promptId, answer: prompt.answer.trim() } : null;
    user.preferences = {
      minAge: Math.min(99, Math.max(18, user.age - 5)),
      maxAge: Math.min(99, Math.max(18, user.age + 5)),
      maxDistanceKm: distance,
      showMe: body.showMe,
    };
    user.onboardingComplete = true;
    return ok(res, myProfile(user));
  });

  router.get('/profile/me', requireAuth, (req, res) => {
    ok(res, myProfile(req.user));
  });

  router.patch('/profile/me', requireAuth, (req, res) => {
    const { displayName, bio, interests: labels } = req.body ?? {};
    if (displayName != null) {
      const name = String(displayName).trim();
      if (!name || name.length > 40) {
        return fail(res, 'VALIDATION_ERROR', 'Please correct the highlighted fields.', [
          { field: 'displayName', reason: 'LENGTH_1_40' },
        ]);
      }
      req.user.displayName = name;
    }
    if (bio != null) {
      const text = String(bio).trim();
      if (text.length > 500) {
        return fail(res, 'VALIDATION_ERROR', 'Please correct the highlighted fields.', [
          { field: 'bio', reason: 'MAX_500' },
        ]);
      }
      req.user.bio = text;
    }
    if (labels != null) {
      if (!Array.isArray(labels) || labels.length > 10) {
        return fail(res, 'VALIDATION_ERROR', 'Please correct the highlighted fields.', [
          { field: 'interests', reason: 'COUNT_1_10' },
        ]);
      }
      req.user.interests = labels.map(String);
    }
    return ok(res, myProfile(req.user));
  });

  router.put('/profile/preferences', requireAuth, (req, res) => {
    const { minAge, maxAge, maxDistanceKm, showMe } = req.body ?? {};
    const details = [];
    if (!Number.isInteger(minAge) || minAge < 18 || minAge > 99) {
      details.push({ field: 'minAge', reason: 'RANGE' });
    }
    if (!Number.isInteger(maxAge) || maxAge < 18 || maxAge > 99 || maxAge < minAge) {
      details.push({ field: 'maxAge', reason: 'RANGE' });
    }
    if (!Number.isInteger(maxDistanceKm) || maxDistanceKm < 1 || maxDistanceKm > 500) {
      details.push({ field: 'maxDistanceKm', reason: 'RANGE_1_500' });
    }
    if (!allowedShowMe.has(showMe)) details.push({ field: 'showMe', reason: 'INVALID' });
    if (details.length) {
      return fail(res, 'VALIDATION_ERROR', 'Please correct the highlighted fields.', details);
    }
    req.user.preferences = { minAge, maxAge, maxDistanceKm, showMe };
    return ok(res, req.user.preferences);
  });

  router.get('/profiles/:userId', requireAuth, (req, res) => {
    const person = findPerson(req.params.userId);
    if (
      !person ||
      person.id === req.user.id ||
      isBlocked(req.user.id, person.id) ||
      person.status === 'SUSPENDED' ||
      person.status === 'BANNED'
    ) {
      return fail(res, 'NOT_FOUND', 'We could not find what you were looking for.');
    }
    return ok(res, publicProfile(person));
  });

  router.get('/discovery', requireAuth, (req, res) => {
    const minAge = Number(req.query.minAge ?? req.user.preferences.minAge);
    const maxAge = Number(req.query.maxAge ?? req.user.preferences.maxAge);
    const distanceKm = Number(req.query.distanceKm ?? req.user.preferences.maxDistanceKm);
    const swiped = new Set(
      store.swipes
        .filter((swipe) => swipe.userId === req.user.id)
        .map((swipe) => swipe.targetUserId),
    );
    const matched = new Set(
      userMatches(req.user.id).map((item) =>
        item.userId === req.user.id ? item.otherUserId : item.userId,
      ),
    );
    const items = [...store.profiles.values()].filter((person) => {
      if (person.id === req.user.id || swiped.has(person.id) || matched.has(person.id)) {
        return false;
      }
      if (isBlocked(req.user.id, person.id)) return false;
      if (person.status === 'SUSPENDED' || person.status === 'BANNED') return false;
      if (person.age < minAge || person.age > maxAge) return false;
      if (person.distanceKm != null && person.distanceKm > distanceKm) return false;
      return true;
    });
    const result = page(items, req.query);
    return ok(res, {
      items: result.items.map((person) => publicProfile(person)),
      nextCursor: result.nextCursor,
    });
  });

  router.post('/swipes', requireAuth, (req, res) => {
    if (replay(req, res)) return undefined;
    const { targetUserId, action } = req.body ?? {};
    const target = store.profiles.get(targetUserId);
    if (
      isBlocked(req.user.id, targetUserId) ||
      target?.status === 'SUSPENDED' ||
      target?.status === 'BANNED'
    ) {
      return fail(res, 'NOT_FOUND', 'We could not find what you were looking for.');
    }
    if (!allowedActions.has(action) || !store.profiles.has(targetUserId)) {
      return fail(res, 'VALIDATION_ERROR', 'Please correct the highlighted fields.', [
        { field: 'targetUserId', reason: 'INVALID' },
      ]);
    }
    const existing = store.swipes.find(
      (swipe) => swipe.userId === req.user.id && swipe.targetUserId === targetUserId,
    );
    if (existing) return fail(res, 'CONFLICT', 'This action was already completed.');

    const swipe = {
      id: createId('swp'),
      userId: req.user.id,
      targetUserId,
      action,
      createdAt: new Date().toISOString(),
    };
    store.swipes.push(swipe);

    let match = null;
    if (action !== 'PASS' && store.likedMe.has(targetUserId)) {
      const conversationId = createId('cnv');
      const record = {
        id: createId('mat'),
        userId: req.user.id,
        otherUserId: targetUserId,
        matchedAt: new Date().toISOString(),
        conversationId,
      };
      store.matches.push(record);
      store.conversations.set(conversationId, {
        id: conversationId,
        matchId: record.id,
        userIds: [req.user.id, targetUserId],
      });
      match = matchFor(record);
      emitToUsers([targetUserId], 'match:new', {
        match: {
          id: record.id,
          otherUser: publicProfile(req.user),
          matchedAt: record.matchedAt,
          conversationId,
        },
      });
      pushNotice(targetUserId, 'NEW_MATCH', 'New match', 'You have a new match', {
        matchId: record.id,
        conversationId,
      });
    }
    return ok(res, remember(req, { swipeId: swipe.id, match }));
  });

  router.post('/swipes/undo', requireAuth, (req, res) => {
    if (!req.user.entitlement?.isActive) {
      return fail(res, 'SUBSCRIPTION_REQUIRED', 'This needs a premium plan.', [
        { field: 'undo', reason: 'FREE_TIER' },
      ]);
    }
    const mine = store.swipes.filter((swipe) => swipe.userId === req.user.id);
    const last = mine.at(-1);
    if (!last) return fail(res, 'NOT_FOUND', 'We could not find what you were looking for.');
    store.swipes.splice(store.swipes.lastIndexOf(last), 1);
    const created = store.matches.find(
      (item) => item.userId === req.user.id && item.otherUserId === last.targetUserId,
    );
    if (created) {
      emitToUsers([req.user.id, created.otherUserId], 'match:removed', {
        matchId: created.id,
        conversationId: created.conversationId,
      });
      store.matches.splice(store.matches.indexOf(created), 1);
      store.conversations.delete(created.conversationId);
    }
    return ok(res, { restoredProfile: publicProfile(store.profiles.get(last.targetUserId)) });
  });

  router.get('/matches', requireAuth, (req, res) => {
    const result = page(userMatches(req.user.id).slice().reverse(), req.query);
    return ok(res, {
      items: result.items.map((item) => matchFor(item)),
      nextCursor: result.nextCursor,
    });
  });

  router.post('/matches/:matchId/unmatch', requireAuth, (req, res) => {
    const index = store.matches.findIndex(
      (item) =>
        item.id === req.params.matchId &&
        (item.userId === req.user.id || item.otherUserId === req.user.id),
    );
    if (index < 0) return fail(res, 'NOT_FOUND', 'We could not find what you were looking for.');
    const [removed] = store.matches.splice(index, 1);
    store.conversations.delete(removed.conversationId);
    emitToUsers([removed.userId, removed.otherUserId], 'match:removed', {
      matchId: removed.id,
      conversationId: removed.conversationId,
    });
    return ok(res, { unmatched: true });
  });

  router.get('/conversations', requireAuth, (req, res) => {
    const mine = [...store.conversations.values()].filter((conversation) =>
      conversation.userIds.includes(req.user.id),
    );
    const result = page(mine, req.query);
    return ok(res, {
      items: result.items.map((conversation) => conversationJson(req.user, conversation)),
      nextCursor: result.nextCursor,
    });
  });

  router.get('/conversations/:conversationId', requireAuth, (req, res) => {
    const conversation = store.conversations.get(req.params.conversationId);
    if (!conversation?.userIds.includes(req.user.id)) {
      return fail(res, 'NOT_FOUND', 'We could not find what you were looking for.');
    }
    return ok(res, conversationJson(req.user, conversation));
  });

  router.get('/conversations/:conversationId/messages', requireAuth, (req, res) => {
    const conversation = store.conversations.get(req.params.conversationId);
    if (!conversation?.userIds.includes(req.user.id)) {
      return fail(res, 'MATCH_REQUIRED', 'You can message someone after you match.');
    }
    const result = page(
      store.messages.filter((message) => message.conversationId === conversation.id),
      req.query,
    );
    return ok(res, result);
  });

  router.post('/conversations/:conversationId/messages', requireAuth, (req, res) => {
    if (replay(req, res)) return undefined;
    const conversation = store.conversations.get(req.params.conversationId);
    if (!conversation?.userIds.includes(req.user.id)) {
      return fail(res, 'MATCH_REQUIRED', 'You can message someone after you match.');
    }
    const text = String(req.body?.text || '').trim();
    const attachmentId = req.body?.attachmentMediaId;
    let attachment = null;
    if (attachmentId != null) {
      const media = store.media.get(attachmentId);
      if (
        !media ||
        media.ownerId !== req.user.id ||
        media.purpose !== 'CHAT_ATTACHMENT' ||
        media.status !== 'READY'
      ) {
        return fail(res, 'VALIDATION_ERROR', 'Please correct the highlighted fields.', [
          { field: 'attachmentMediaId', reason: 'UNKNOWN_MEDIA' },
        ]);
      }
      attachment = {
        mediaId: media.id,
        url: `${req.protocol}://${req.get('host')}/api/v1/media/files/${media.id}`,
      };
    }
    if ((!text && !attachment) || text.length > 2000) {
      return fail(res, 'VALIDATION_ERROR', 'Please correct the highlighted fields.', [
        { field: 'text', reason: 'LENGTH_1_2000' },
      ]);
    }
    const message = {
      id: createId('msg'),
      conversationId: conversation.id,
      senderId: req.user.id,
      text,
      sentAt: new Date().toISOString(),
      status: 'SENT',
      clientMessageId: req.body?.clientMessageId ?? req.get('idempotency-key') ?? null,
      attachment,
    };
    store.messages.push(message);
    emitToUsers(conversation.userIds, 'message:new', { message });
    const otherId = conversation.userIds.find((id) => id !== req.user.id);
    if (otherId) {
      pushNotice(otherId, 'NEW_MESSAGE', 'New message', 'You have a new message', {
        conversationId: conversation.id,
      });
    }
    return ok(res, remember(req, message), 201);
  });

  router.get('/subscriptions/products', requireAuth, (_req, res) => {
    ok(res, { items: store.products });
  });

  router.get('/subscriptions/entitlement', requireAuth, (req, res) => {
    ok(res, req.user.entitlement);
  });

  registerExtended(router, {
    store,
    config,
    requireAuth,
    publicProfile,
    myProfile,
    page,
    findPerson,
    issueTokens,
    ageOn,
    isBlocked,
    dropRelationship,
    markMessagesRead,
  });
  registerAdmin(router, { store, requireAuth, page, findPerson });

  app.use('/api/v1', router);
  app.use((error, _req, res, _next) => {
    if (error?.type === 'entity.too.large') {
      return fail(res, 'MEDIA_REJECTED', 'That photo can’t be used. Choose another one.', [
        { field: 'file', reason: 'TOO_LARGE' },
      ]);
    }
    console.error(error);
    return fail(res, 'SERVER_ERROR', 'Something went wrong. Please try again.');
  });
}
