import { useEffect } from 'react';
import { authApi, type NutriLensProfileResponse } from '@services/api';

const PROFILE_CACHE_KEY = 'nutrilens_profile_cache';
const LAST_SENT_PREFIX = 'nutrilens_reminder_sent';

const reminderSlots = [
  { key: 'breakfast', label: 'breakfast', timeField: 'breakfast_reminder_time' as const },
  { key: 'lunch', label: 'lunch', timeField: 'lunch_reminder_time' as const },
  { key: 'dinner', label: 'dinner', timeField: 'dinner_reminder_time' as const },
];

function getCachedProfile(): NutriLensProfileResponse | null {
  const raw = localStorage.getItem(PROFILE_CACHE_KEY);
  if (!raw) {
    return null;
  }

  try {
    return JSON.parse(raw) as NutriLensProfileResponse;
  } catch {
    return null;
  }
}

function getTodayKey(slot: string): string {
  const today = new Date().toISOString().split('T')[0];
  return `${LAST_SENT_PREFIX}:${today}:${slot}`;
}

function maybeSendReminders(profile: NutriLensProfileResponse): void {
  if (!profile.notifications_enabled || typeof Notification === 'undefined' || Notification.permission !== 'granted') {
    return;
  }

  const now = new Date();
  const currentTime = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;

  reminderSlots.forEach((slot) => {
    const scheduledTime = profile[slot.timeField];
    if (scheduledTime !== currentTime) {
      return;
    }

    const sentKey = getTodayKey(slot.key);
    if (localStorage.getItem(sentKey) === '1') {
      return;
    }

    const notification = new Notification('NutriLens meal reminder', {
      body: `Time to log your ${slot.label}.`,
      tag: `nutrilens-${slot.key}`,
    });
    notification.onclick = () => {
      window.focus();
      window.location.hash = '#/nutrilens';
    };
    localStorage.setItem(sentKey, '1');
  });
}

export function useMealReminders(isEnabled: boolean): void {
  useEffect(() => {
    if (!isEnabled) {
      return;
    }

    let cancelled = false;

    const syncProfile = async () => {
      try {
        const profile = await authApi.getNutriLensProfile('nutrilens');
        if (!cancelled) {
          localStorage.setItem(PROFILE_CACHE_KEY, JSON.stringify(profile));
        }
      } catch {
        // Reminders should fail silently if profile refresh fails.
      }
    };

    syncProfile();

    const runCheck = () => {
      const profile = getCachedProfile();
      if (profile) {
        maybeSendReminders(profile);
      }
    };

    runCheck();
    const intervalId = window.setInterval(runCheck, 60_000);
    const refreshId = window.setInterval(syncProfile, 5 * 60_000);

    return () => {
      cancelled = true;
      window.clearInterval(intervalId);
      window.clearInterval(refreshId);
    };
  }, [isEnabled]);
}
