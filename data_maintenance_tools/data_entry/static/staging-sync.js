(function () {
  const toolbar = document.getElementById('stagingSyncToolbar');
  if (!toolbar) {
    return;
  }

  const syncUrl = toolbar.dataset.syncUrl;
  const urlParams = new URLSearchParams(window.location.search);
  const urgentSync = urlParams.get('sync_pending') === '1';
  const debounceSeconds = urgentSync
    ? 2
    : Number(toolbar.dataset.debounceSeconds || '10');
  const statusText = document.getElementById('stagingSyncStatusText');
  const syncNowBtn = document.getElementById('stagingSyncNowBtn');
  let debounceTimer = null;
  let syncInFlight = false;

  function setStatus(label) {
    if (statusText) {
      statusText.textContent = label;
    }
  }

  function scheduleAutoSync() {
    if (toolbar.dataset.autoSync !== '1') {
      return;
    }
    if (debounceTimer) {
      window.clearTimeout(debounceTimer);
    }
    debounceTimer = window.setTimeout(function () {
      runSync(false);
    }, Math.max(1, debounceSeconds) * 1000);
  }

  async function runSync(manual) {
    if (!syncUrl || syncInFlight) {
      return;
    }
    syncInFlight = true;
    if (syncNowBtn) {
      syncNowBtn.disabled = true;
    }
    if (statusText) {
      setStatus(manual ? 'Syncing to Dropbox…' : 'Sync pending…');
    }

    try {
      const resp = await fetch(syncUrl, {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
        },
      });
      const payload = await resp.json();
      if (!resp.ok || !payload.ok) {
        throw new Error(payload.error || 'Sync failed.');
      }
      if (urgentSync) {
        urlParams.delete('sync_pending');
        const next = urlParams.toString();
        const nextUrl = next
          ? window.location.pathname + '?' + next
          : window.location.pathname;
        window.history.replaceState({}, '', nextUrl);
      }
      window.location.reload();
    } catch (err) {
      toolbar.dataset.autoSync = '1';
      if (statusText) {
        setStatus('Sync failed — ' + err.message);
      }
      syncInFlight = false;
      if (syncNowBtn) {
        syncNowBtn.disabled = false;
      }
    }
  }

  if (syncNowBtn) {
    syncNowBtn.addEventListener('click', function () {
      if (debounceTimer) {
        window.clearTimeout(debounceTimer);
      }
      runSync(true);
    });
  }

  scheduleAutoSync();
})();
