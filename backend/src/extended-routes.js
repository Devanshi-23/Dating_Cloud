import crypto from 'node:crypto';
import { fail, ok } from './http.js';
import { emitToUsers } from './realtime-hub.js';
import { blankMemberAccount, createId } from './store.js';

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const reportReasons = new Set([
  'FAKE_PROFILE',
  'INAPPROPRIATE_PHOTOS',
  'HARASSMENT',
  'SPAM_OR_SCAM',
  'UNDERAGE',
  'OFFLINE_BEHAVIOUR',
  'OTHER',
]);
const ticketCategories = new Set(['ACCOUNT', 'BILLING', 'SAFETY', 'BUG', 'OTHER']);
const providers = new Set(['apple', 'google']);
const platforms = new Set(['IOS', 'ANDROID']);

const faqs = [
  {
    id: 'faq_safety',
    category: 'Safety',
    question: 'How do I block or report someone?',
    answer:
      'Open their profile or chat, then choose Block or Report. Blocking also ends a match.',
  },
  {
    id: 'faq_photos',
    category: 'Profile',
    question: 'How many photos can I add?',
    answer: 'Between 2 and 6 while signing up, and up to 6 on your profile afterwards.',
  },
  {
    id: 'faq_premium',
    category: 'Premium',
    question: 'What does Premium include?',
    answer: 'Premium shows who liked you. Plus adds undo. Purchases are verified by the server.',
  },
  {
    id: 'faq_delete',
    category: 'Account',
    question: 'What happens if I delete my account?',
    answer:
      'Your profile is hidden immediately and erased after 14 days. Signing in during that time cancels deletion.',
  },
];

function hashPassword(password, salt = crypto.randomBytes(16).toString('hex')) {
  const hash = crypto.scryptSync(password, salt, 32).toString('hex');
  return { salt, hash };
}

function passwordMatches(password, saved) {
  const hash = crypto.scryptSync(password, saved.salt, 32).toString('hex');
  return crypto.timingSafeEqual(Buffer.from(hash, 'hex'), Buffer.from(saved.hash, 'hex'));
}

function validation(res, details) {
  return fail(res, 'VALIDATION_ERROR', 'Please correct the highlighted fields.', details);
}

function entitlementOf(user) {
  return {
    tier: user.entitlement?.tier ?? 'FREE',
    isActive: Boolean(user.entitlement?.isActive),
    expiresAt: user.entitlement?.expiresAt ?? null,
    willRenew: Boolean(user.entitlement?.willRenew),
    platform: user.entitlement?.platform ?? null,
  };
}

function authResult(user, tokens, isNewUser, status = 200) {
  return {
    status,
    body: {
      isNewUser,
      user: { id: user.id, onboardingComplete: user.onboardingComplete },
      tokens: { ...tokens, expiresIn: 900 },
    },
  };
}

export function registerExtended(router, ctx) {
  const {
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
  } = ctx;

  function ensurePhotos(user) {
    if (!Array.isArray(user.photos)) {
      user.photos = (user.photoUrls ?? []).map((url, order) => ({
        id: `pho_${user.id}_${order}`,
        url,
        mediaId: null,
      }));
    }
    user.photoUrls = user.photos.map((photo) => photo.url);
    return user.photos;
  }

  function ownReadyMedia(userId, mediaId, purpose) {
    const item = store.media.get(mediaId);
    if (!item || item.ownerId !== userId || item.status !== 'READY') return null;
    if (purpose && item.purpose && item.purpose !== purpose) return null;
    return item;
  }

  function cancelDeletion(user) {
    if (user?.deletion) user.deletion = null;
  }

  router.post('/auth/register', (req, res) => {
    const email = String(req.body?.email || '').trim().toLowerCase();
    const password = String(req.body?.password || '');
    const displayName = String(req.body?.displayName || '').trim();
    const details = [];
    if (!emailPattern.test(email)) details.push({ field: 'email', reason: 'EMAIL' });
    if (password.length < 10 || password.length > 128) {
      details.push({ field: 'password', reason: 'LENGTH_10_128' });
    }
    if (!displayName || displayName.length > 40) {
      details.push({ field: 'displayName', reason: 'LENGTH_1_40' });
    }
    if (req.body?.acceptedTermsVersion !== config.termsVersion) {
      details.push({ field: 'acceptedTermsVersion', reason: 'NOT_CURRENT' });
    }
    if (details.length) return validation(res, details);
    if (store.credentials.has(email)) {
      return fail(res, 'CONFLICT', 'An account with that email already exists.');
    }
    const dateOfBirth = new Date(`${req.body?.dateOfBirth}T00:00:00.000Z`);
    if (Number.isNaN(dateOfBirth.getTime())) {
      return validation(res, [{ field: 'dateOfBirth', reason: 'DATE' }]);
    }
    if (ageOn(dateOfBirth, new Date()) < 18) {
      return fail(res, 'ACCOUNT_INELIGIBLE', 'This account is not eligible.');
    }
    const user = blankMemberAccount(createId('usr'), null);
    user.email = email;
    user.displayName = displayName;
    user.dateOfBirth = req.body.dateOfBirth;
    user.age = ageOn(dateOfBirth, new Date());
    store.users.set(user.id, user);
    store.credentials.set(email, { userId: user.id, ...hashPassword(password) });
    const result = authResult(user, issueTokens(user.id), true, 201);
    return ok(res, result.body, result.status);
  });

  router.post('/auth/login', (req, res) => {
    const email = String(req.body?.email || '').trim().toLowerCase();
    const password = String(req.body?.password || '');
    const saved = store.credentials.get(email);
    const user = saved ? store.users.get(saved.userId) : null;
    if (!user || !passwordMatches(password, saved)) {
      return fail(res, 'UNAUTHENTICATED', 'That email or password is incorrect.');
    }
    if (user.status === 'BANNED') {
      return fail(res, 'ACCOUNT_INELIGIBLE', 'This account is not eligible.');
    }
    cancelDeletion(user);
    const result = authResult(user, issueTokens(user.id), false);
    return ok(res, result.body);
  });

  router.post('/auth/social/:provider', (req, res) => {
    if (!providers.has(req.params.provider)) {
      return validation(res, [{ field: 'provider', reason: 'INVALID' }]);
    }
    return fail(
      res,
      'FEATURE_NOT_CONFIGURED',
      'Social sign-in is not configured on this server.',
    );
  });

  router.put('/profile/interests', requireAuth, (req, res) => {
    const catalogue = new Map(store.interests.map((item) => [item.id, item]));
    const interestIds = Array.isArray(req.body?.interestIds) ? req.body.interestIds : [];
    if (
      interestIds.length < 1 ||
      interestIds.length > 10 ||
      !interestIds.every((id) => catalogue.has(id))
    ) {
      return validation(res, [{ field: 'interestIds', reason: 'COUNT_1_10' }]);
    }
    req.user.interests = interestIds.map((id) => catalogue.get(id).label);
    req.user.interestIds = interestIds;
    return ok(res, myProfile(req.user));
  });

  router.post('/profile/photos', requireAuth, (req, res) => {
    const photos = ensurePhotos(req.user);
    const item = ownReadyMedia(req.user.id, req.body?.mediaId, 'PROFILE_PHOTO');
    if (!item) {
      return fail(res, 'MEDIA_REJECTED', 'That photo can’t be used. Choose another one.', [
        { field: 'mediaId', reason: 'NOT_READY' },
      ]);
    }
    if (photos.length >= 6) {
      return fail(res, 'CONFLICT', 'You can keep up to 6 photos.');
    }
    if (photos.some((photo) => photo.mediaId === item.id)) {
      return fail(res, 'CONFLICT', 'This action was already completed.');
    }
    photos.push({
      id: `pho_${item.id}`,
      mediaId: item.id,
      url: `${req.protocol}://${req.get('host')}/api/v1/media/files/${item.id}`,
    });
    ensurePhotos(req.user);
    return ok(res, myProfile(req.user), 201);
  });

  router.patch('/profile/photos/order', requireAuth, (req, res) => {
    const photos = ensurePhotos(req.user);
    const photoIds = Array.isArray(req.body?.photoIds) ? req.body.photoIds : [];
    const current = photos.map((photo) => photo.id);
    const same =
      photoIds.length === current.length &&
      photoIds.every((id) => current.includes(id)) &&
      new Set(photoIds).size === photoIds.length;
    if (!same) return validation(res, [{ field: 'photoIds', reason: 'INVALID' }]);
    const byId = new Map(photos.map((photo) => [photo.id, photo]));
    req.user.photos = photoIds.map((id) => byId.get(id));
    ensurePhotos(req.user);
    return ok(res, myProfile(req.user));
  });

  router.delete('/profile/photos/:photoId', requireAuth, (req, res) => {
    const photos = ensurePhotos(req.user);
    const index = photos.findIndex((photo) => photo.id === req.params.photoId);
    if (index < 0) return fail(res, 'NOT_FOUND', 'We could not find what you were looking for.');
    if (photos.length < 2) {
      return fail(res, 'CONFLICT', 'Keep at least one photo on your profile.');
    }
    photos.splice(index, 1);
    ensurePhotos(req.user);
    return ok(res, myProfile(req.user));
  });

  router.post('/profile/verification', requireAuth, (req, res) => {
    const dayAgo = Date.now() - 86400000;
    const recent = (req.user.verificationAttempts ?? []).filter((at) => at > dayAgo);
    if (recent.length >= 3) {
      return fail(res, 'RATE_LIMITED', 'Too many attempts. Please wait and try again.');
    }
    const item = ownReadyMedia(req.user.id, req.body?.selfieMediaId, 'VERIFICATION_SELFIE');
    if (!item) {
      return fail(res, 'MEDIA_REJECTED', 'That photo can’t be used. Choose another one.', [
        { field: 'selfieMediaId', reason: 'NOT_READY' },
      ]);
    }
    const submittedAt = new Date().toISOString();
    req.user.verificationAttempts = [...recent, Date.now()];
    req.user.verification = { status: 'PENDING', submittedAt };
    return ok(res, req.user.verification, 202);
  });

  router.get('/media/:mediaId', requireAuth, (req, res) => {
    const item = store.media.get(req.params.mediaId);
    if (!item || item.ownerId !== req.user.id || item.status !== 'READY') {
      return fail(res, 'NOT_FOUND', 'We could not find what you were looking for.');
    }
    return ok(res, {
      id: item.id,
      status: item.status,
      contentType: item.contentType,
      url: `${req.protocol}://${req.get('host')}/api/v1/media/files/${item.id}`,
    });
  });

  router.get('/likes/received', requireAuth, (req, res) => {
    const swiped = new Set(
      store.swipes.filter((swipe) => swipe.userId === req.user.id).map((swipe) => swipe.targetUserId),
    );
    const items = [...store.likedMe]
      .filter((id) => !swiped.has(id) && !isBlocked(req.user.id, id) && findPerson(id))
      .map((id) => {
        const meta = store.likeMeta.get(id) ?? { action: 'LIKE', likedAt: new Date().toISOString() };
        return {
          user: publicProfile(findPerson(id)),
          action: meta.action,
          likedAt: meta.likedAt,
        };
      });
    const premium = req.user.entitlement?.isActive && req.user.entitlement.tier === 'PREMIUM';
    if (!premium) {
      return fail(res, 'SUBSCRIPTION_REQUIRED', 'This needs a premium plan.', [
        { field: 'likes', reason: `COUNT_${items.length}` },
      ]);
    }
    const result = page(items, req.query);
    return ok(res, result);
  });

  router.get('/likes/sent', requireAuth, (req, res) => {
    const matched = new Set(
      store.matches.flatMap((item) =>
        item.userId === req.user.id || item.otherUserId === req.user.id
          ? [item.userId, item.otherUserId]
          : [],
      ),
    );
    const items = store.swipes
      .filter(
        (swipe) =>
          swipe.userId === req.user.id &&
          swipe.action !== 'PASS' &&
          !matched.has(swipe.targetUserId) &&
          !isBlocked(req.user.id, swipe.targetUserId),
      )
      .map((swipe) => ({
        user: publicProfile(findPerson(swipe.targetUserId)),
        action: swipe.action,
        likedAt: swipe.createdAt,
      }));
    const result = page(items, req.query);
    return ok(res, result);
  });

  router.get('/matches/:matchId', requireAuth, (req, res) => {
    const record = store.matches.find(
      (item) =>
        item.id === req.params.matchId &&
        (item.userId === req.user.id || item.otherUserId === req.user.id),
    );
    if (!record) return fail(res, 'NOT_FOUND', 'We could not find what you were looking for.');
    const otherId = record.userId === req.user.id ? record.otherUserId : record.userId;
    return ok(res, {
      id: record.id,
      otherUser: publicProfile(findPerson(otherId)),
      matchedAt: record.matchedAt,
      conversationId: record.conversationId,
    });
  });

  router.post('/messages/:messageId/read', requireAuth, (req, res) => {
    const message = store.messages.find((item) => item.id === req.params.messageId);
    if (!message || !markMessagesRead(req.user.id, message)) {
      return fail(res, 'NOT_FOUND', 'We could not find what you were looking for.');
    }
    return ok(res, null);
  });

  router.post('/messages/:messageId/report', requireAuth, (req, res) => {
    const message = store.messages.find((item) => item.id === req.params.messageId);
    const conversation = message ? store.conversations.get(message.conversationId) : null;
    if (!conversation?.userIds.includes(req.user.id) || message.senderId === req.user.id) {
      return fail(res, 'NOT_FOUND', 'We could not find what you were looking for.');
    }
    const reason = req.body?.reason;
    if (!reportReasons.has(reason)) return validation(res, [{ field: 'reason', reason: 'INVALID' }]);
    const report = {
      id: createId('rpt'),
      reporterId: req.user.id,
      targetType: 'MESSAGE',
      targetId: message.id,
      reason,
      details: req.body?.details ?? null,
      status: 'OPEN',
      createdAt: new Date().toISOString(),
    };
    store.reports.push(report);
    if (req.body?.alsoBlock !== false) {
      const sender = findPerson(message.senderId);
      dropRelationship(req.user.id, message.senderId);
      if (sender && !isBlocked(req.user.id, sender.id)) {
        store.blocks.push({
          userId: req.user.id,
          blockedUserId: sender.id,
          blockedAt: new Date().toISOString(),
          displayName: sender.displayName,
        });
      }
    }
    return ok(res, { id: report.id, status: report.status, createdAt: report.createdAt }, 201);
  });

  router.post('/users/:userId/block', requireAuth, (req, res) => {
    const person = findPerson(req.params.userId);
    if (!person || person.id === req.user.id) {
      return fail(res, 'NOT_FOUND', 'We could not find what you were looking for.');
    }
    if (!store.blocks.some((item) => item.userId === req.user.id && item.blockedUserId === person.id)) {
      dropRelationship(req.user.id, person.id);
      store.blocks.push({
        userId: req.user.id,
        blockedUserId: person.id,
        blockedAt: new Date().toISOString(),
        displayName: person.displayName,
      });
    }
    return ok(res, null);
  });

  router.delete('/users/:userId/block', requireAuth, (req, res) => {
    const index = store.blocks.findIndex(
      (item) => item.userId === req.user.id && item.blockedUserId === req.params.userId,
    );
    if (index >= 0) store.blocks.splice(index, 1);
    return ok(res, null);
  });

  router.get('/blocks', requireAuth, (req, res) => {
    const items = store.blocks
      .filter((item) => item.userId === req.user.id)
      .map((item) => ({
        user: { id: item.blockedUserId, displayName: item.displayName },
        blockedAt: item.blockedAt,
      }));
    return ok(res, page(items, req.query));
  });

  router.post('/reports', requireAuth, (req, res) => {
    const { targetType, targetId, reason } = req.body ?? {};
    if (!['USER', 'PHOTO'].includes(targetType) || !reportReasons.has(reason) || !targetId) {
      return validation(res, [{ field: 'reason', reason: 'INVALID' }]);
    }
    const today = store.reports.filter(
      (item) => item.reporterId === req.user.id && Date.now() - Date.parse(item.createdAt) < 86400000,
    );
    if (today.length >= 20) {
      return fail(res, 'RATE_LIMITED', 'Too many attempts. Please wait and try again.');
    }
    const report = {
      id: createId('rpt'),
      reporterId: req.user.id,
      targetType,
      targetId,
      reason,
      details: req.body?.details ?? null,
      status: 'OPEN',
      createdAt: new Date().toISOString(),
    };
    store.reports.push(report);
    if (req.body?.alsoBlock !== false && targetType === 'USER') {
      const person = findPerson(targetId);
      if (person && person.id !== req.user.id) {
        if (!isBlocked(req.user.id, person.id)) {
          dropRelationship(req.user.id, person.id);
          store.blocks.push({
            userId: req.user.id,
            blockedUserId: person.id,
            blockedAt: new Date().toISOString(),
            displayName: person.displayName,
          });
        }
      }
    }
    return ok(res, { id: report.id, status: report.status, createdAt: report.createdAt }, 201);
  });

  router.post('/devices', requireAuth, (req, res) => {
    const { platform, pushToken } = req.body ?? {};
    if (!platforms.has(platform) || typeof pushToken !== 'string' || pushToken.length < 8) {
      return validation(res, [{ field: 'pushToken', reason: 'INVALID' }]);
    }
    let device = store.devices.find((item) => item.userId === req.user.id && item.pushToken === pushToken);
    if (!device) {
      device = {
        id: createId('dev'),
        userId: req.user.id,
        platform,
        pushToken,
        appVersion: req.body?.appVersion ?? null,
        locale: req.body?.locale ?? null,
        lastSeenAt: new Date().toISOString(),
      };
      store.devices.push(device);
    } else {
      device.platform = platform;
      device.lastSeenAt = new Date().toISOString();
    }
    return ok(res, { id: device.id, platform: device.platform, lastSeenAt: device.lastSeenAt });
  });

  router.delete('/devices/:deviceId', requireAuth, (req, res) => {
    const index = store.devices.findIndex(
      (item) => item.id === req.params.deviceId && item.userId === req.user.id,
    );
    if (index < 0) return fail(res, 'NOT_FOUND', 'We could not find what you were looking for.');
    store.devices.splice(index, 1);
    return ok(res, null);
  });

  router.get('/notifications', requireAuth, (req, res) => {
    const mine = store.notifications.filter((item) => item.userId === req.user.id);
    const result = page(mine, req.query);
    return ok(res, {
      items: result.items.map(({ userId, ...item }) => item),
      nextCursor: result.nextCursor,
    });
  });

  router.post('/notifications/:notificationId/read', requireAuth, (req, res) => {
    const item = store.notifications.find(
      (notification) =>
        notification.id === req.params.notificationId && notification.userId === req.user.id,
    );
    if (!item) return fail(res, 'NOT_FOUND', 'We could not find what you were looking for.');
    item.readAt = item.readAt ?? new Date().toISOString();
    return ok(res, null);
  });

  router.get('/notification-preferences', requireAuth, (req, res) => {
    ok(res, req.user.notificationPreferences);
  });

  router.patch('/notification-preferences', requireAuth, (req, res) => {
    const current = { ...req.user.notificationPreferences };
    for (const key of ['newMatches', 'messages', 'likes', 'promotions']) {
      if (req.body?.[key] != null) {
        if (typeof req.body[key] !== 'boolean') {
          return validation(res, [{ field: key, reason: 'BOOLEAN' }]);
        }
        current[key] = req.body[key];
      }
    }
    req.user.notificationPreferences = current;
    return ok(res, current);
  });

  router.post('/subscriptions/verify', requireAuth, (req, res) => {
    const { platform, productId, transactionProof } = req.body ?? {};
    const product = store.products.find((item) => item.id === productId);
    if (!platforms.has(platform) || !product || typeof transactionProof !== 'string') {
      return validation(res, [{ field: 'transactionProof', reason: 'INVALID' }]);
    }
    if (transactionProof.length < 10) {
      return fail(res, 'FEATURE_NOT_CONFIGURED', 'Store billing is not configured.');
    }
    const taken = store.purchases.find((item) => item.proof === transactionProof);
    if (taken && taken.userId !== req.user.id) {
      return fail(res, 'CONFLICT', 'This purchase is already linked to another account.');
    }
    if (!taken) {
      store.purchases.push({
        userId: req.user.id,
        productId: product.id,
        proof: transactionProof,
        platform,
      });
    }
    const days = product.period === 'YEARLY' ? 365 : 30;
    req.user.entitlement = {
      tier: product.tier,
      isActive: true,
      expiresAt: new Date(Date.now() + days * 86400000).toISOString(),
      willRenew: true,
      platform,
    };
    emitToUsers([req.user.id], 'entitlement:updated', {
      tier: req.user.entitlement.tier,
      isActive: req.user.entitlement.isActive,
    });
    return ok(res, entitlementOf(req.user));
  });

  router.post('/subscriptions/restore', requireAuth, (req, res) => {
    const proofs = Array.isArray(req.body?.transactionProofs) ? req.body.transactionProofs : [];
    const owned = store.purchases.filter(
      (item) => item.userId === req.user.id && (proofs.length === 0 || proofs.includes(item.proof)),
    );
    if (!owned.length) {
      req.user.entitlement = {
        tier: 'FREE',
        isActive: false,
        expiresAt: null,
        willRenew: false,
        platform: null,
      };
    }
    emitToUsers([req.user.id], 'entitlement:updated', {
      tier: req.user.entitlement.tier,
      isActive: Boolean(req.user.entitlement.isActive),
    });
    return ok(res, entitlementOf(req.user));
  });

  router.get('/support/faqs', (_req, res) => {
    ok(res, { items: faqs });
  });

  router.post('/support/tickets', requireAuth, (req, res) => {
    const category = req.body?.category;
    const subject = String(req.body?.subject || '').trim();
    const message = String(req.body?.message || '').trim();
    const details = [];
    if (!ticketCategories.has(category)) details.push({ field: 'category', reason: 'INVALID' });
    if (subject.length < 3 || subject.length > 120) {
      details.push({ field: 'subject', reason: 'LENGTH_3_120' });
    }
    if (message.length < 10 || message.length > 5000) {
      details.push({ field: 'message', reason: 'LENGTH_10_5000' });
    }
    if (details.length) return validation(res, details);
    const today = store.tickets.filter(
      (item) => item.userId === req.user.id && Date.now() - Date.parse(item.createdAt) < 86400000,
    );
    if (today.length >= 5) {
      return fail(res, 'RATE_LIMITED', 'Too many attempts. Please wait and try again.');
    }
    const ticket = {
      id: createId('tck'),
      userId: req.user.id,
      category,
      subject,
      status: 'OPEN',
      createdAt: new Date().toISOString(),
      messages: [{ author: 'member', text: message, sentAt: new Date().toISOString() }],
    };
    store.tickets.push(ticket);
    return ok(
      res,
      {
        id: ticket.id,
        category: ticket.category,
        subject: ticket.subject,
        status: ticket.status,
        createdAt: ticket.createdAt,
      },
      201,
    );
  });

  router.get('/support/tickets/:ticketId', requireAuth, (req, res) => {
    const ticket = store.tickets.find(
      (item) => item.id === req.params.ticketId && item.userId === req.user.id,
    );
    if (!ticket) return fail(res, 'NOT_FOUND', 'We could not find what you were looking for.');
    return ok(res, {
      id: ticket.id,
      category: ticket.category,
      subject: ticket.subject,
      status: ticket.status,
      createdAt: ticket.createdAt,
      messages: ticket.messages,
    });
  });

  router.post('/account/deletion-request', requireAuth, (req, res) => {
    if (req.body?.confirm !== true) {
      return validation(res, [{ field: 'confirm', reason: 'REQUIRED' }]);
    }
    const scheduledFor = new Date(Date.now() + 14 * 86400000).toISOString();
    req.user.deletion = { status: 'SCHEDULED', scheduledFor };
    return ok(
      res,
      {
        status: 'SCHEDULED',
        scheduledFor,
        activeStoreSubscription: Boolean(req.user.entitlement?.isActive),
      },
      202,
    );
  });

  router.get('/account/export-status', requireAuth, (req, res) => {
    ok(res, req.user.exportStatus ?? { status: 'NONE' });
  });
}
