import { useState, useEffect, useRef } from 'react';

const POLL_INTERVAL_MS = 5 * 60 * 1000; // 5 minutes

async function fetchVersion(): Promise<string | null> {
  try {
    const res = await fetch(`./version.json?t=${Date.now()}`, { cache: 'no-store' });
    if (!res.ok) return null;
    const data = await res.json();
    return typeof data.version === 'string' ? data.version : null;
  } catch {
    return null;
  }
}

export function useVersionCheck(): boolean {
  const [updateAvailable, setUpdateAvailable] = useState(false);
  const initialVersion = useRef<string | null>(null);

  useEffect(() => {
    // Record the version the app launched with
    fetchVersion().then(v => {
      initialVersion.current = v;
    });

    const interval = setInterval(async () => {
      const latest = await fetchVersion();
      if (latest && initialVersion.current && latest !== initialVersion.current) {
        setUpdateAvailable(true);
        clearInterval(interval); // stop polling once update is found
      }
    }, POLL_INTERVAL_MS);

    return () => clearInterval(interval);
  }, []);

  return updateAvailable;
}
