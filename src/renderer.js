let currentSettings = {};

async function loadSettings() {
  currentSettings = await window.electronAPI.getSettings();
  document.getElementById('pi-address').value = currentSettings.piAddress || '';
  document.getElementById('pi-port').value = currentSettings.piPort || '8080';
}

let snackbarTimeout;

function showSnackbar(message, type = 'success') {
  const snackbar = document.getElementById('snackbar');
  const icon = snackbar.querySelector('.snackbar-icon');
  const messageEl = snackbar.querySelector('.snackbar-message');
  
  // Clear any existing timeout
  if (snackbarTimeout) {
    clearTimeout(snackbarTimeout);
  }
  
  // Set icon based on type
  if (type === 'success') {
    icon.textContent = 'check_circle';
  } else if (type === 'error') {
    icon.textContent = 'error';
  }
  
  // Set message and show
  messageEl.textContent = message;
  snackbar.className = `snackbar ${type}`;
  snackbar.classList.add('show');
  
  // Auto-hide after 4 seconds
  snackbarTimeout = setTimeout(() => {
    snackbar.classList.remove('show');
  }, 4000);
}

document.querySelectorAll('.announcement-btn[data-audio]').forEach(btn => {
  btn.addEventListener('click', async () => {
    const audioFile = btn.getAttribute('data-audio');
    const result = await window.electronAPI.playAnnouncement(audioFile);
    
    if (result.success) {
      showSnackbar(result.message, 'success');
    } else {
      showSnackbar(result.message, 'error');
    }
  });
});

document.getElementById('settings-icon').addEventListener('click', () => {
  loadSettings();
  document.getElementById('settings-modal').classList.add('show');
});

document.getElementById('cancel-btn').addEventListener('click', () => {
  document.getElementById('settings-modal').classList.remove('show');
});

document.getElementById('save-btn').addEventListener('click', async () => {
  const newSettings = {
    piAddress: document.getElementById('pi-address').value,
    piPort: document.getElementById('pi-port').value
  };
  
  await window.electronAPI.saveSettings(newSettings);
  document.getElementById('settings-modal').classList.remove('show');
  showSnackbar('Settings saved successfully!', 'success');
});

document.getElementById('settings-modal').addEventListener('click', (e) => {
  if (e.target.id === 'settings-modal') {
    document.getElementById('settings-modal').classList.remove('show');
  }
});

window.addEventListener('DOMContentLoaded', () => {
  loadSettings();
  
  // Set up webview with zoom and CSS injection
  const webview = document.getElementById('mainWebview');
  
  webview.addEventListener('dom-ready', () => {
    // Set zoom level to 85%
    webview.setZoomFactor(0.85);
    
    // Inject CSS to hide intercom container
    webview.insertCSS(`
      div#intercom-container {
        display: none !important;
      }
    `);
  });
});