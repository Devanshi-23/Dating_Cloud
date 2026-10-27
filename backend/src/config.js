import path from 'node:path';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';

const backendRoot = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
);

dotenv.config({ path: path.join(backendRoot, '.env') });

function required(name) {
  const value = process.env[name];
  if (!value || !value.trim()) {
    throw new Error(`Missing ${name}. Copy backend/.env.example to backend/.env.`);
  }
  return value.trim();
}

export const config = {
  port: Number(process.env.PORT || 3000),
  jwtAccessSecret: required('JWT_ACCESS_SECRET'),
  jwtRefreshSecret: required('JWT_REFRESH_SECRET'),
  accessTtl: process.env.ACCESS_TOKEN_TTL || '15m',
  refreshTtl: process.env.REFRESH_TOKEN_TTL || '30d',
  devOtpCode: process.env.DEV_OTP_CODE || '123456',
  otpExpiresSeconds: Number(process.env.OTP_EXPIRES_SECONDS || 300),
  otpResendSeconds: Number(process.env.OTP_RESEND_SECONDS || 30),
  demoPhone: process.env.DEMO_PHONE || '+919876543210',
  termsVersion: process.env.TERMS_VERSION || '2026-01',
  staffRoles: parseStaffRoles(process.env.STAFF_ROLES || ''),
};

function parseStaffRoles(raw) {
  const roles = new Map();
  for (const part of raw.split(',')) {
    const [phone, role] = part.split(':').map((item) => item.trim());
    if (phone && (role === 'MODERATOR' || role === 'ADMIN')) roles.set(phone, role);
  }
  return roles;
}
