let currentSettings = {};

async function loadSettings() {
  currentSettings = await window.electronAPI.getSettings();
  document.getElementById('pi-address').value = currentSettings.piAddress || '';
  document.getElementById('pi-port').value = currentSettings.piPort || '8080';
  document.getElementById('api-token').value = currentSettings.apiToken || '';
}

function showToast(message, type = 'success') {
  const toast = document.getElementById('toast');
  toast.textContent = message;
  toast.className = `toast ${type}`;
  toast.classList.add('show');
  
  setTimeout(() => {
    toast.classList.remove('show');
  }, 3000);
}

document.querySelectorAll('.announcement-btn[data-audio]').forEach(btn => {
  btn.addEventListener('click', async () => {
    const audioFile = btn.getAttribute('data-audio');
    const result = await window.electronAPI.playAnnouncement(audioFile);
    
    if (result.success) {
      showToast(result.message, 'success');
    } else {
      showToast(result.message, 'error');
    }
  });
});

document.getElementById('settings-btn').addEventListener('click', () => {
  loadSettings();
  document.getElementById('settings-modal').classList.add('show');
});

document.getElementById('cancel-btn').addEventListener('click', () => {
  document.getElementById('settings-modal').classList.remove('show');
});

document.getElementById('save-btn').addEventListener('click', async () => {
  const newSettings = {
    piAddress: document.getElementById('pi-address').value,
    piPort: document.getElementById('pi-port').value,
    apiToken: document.getElementById('api-token').value
  };
  
  await window.electronAPI.saveSettings(newSettings);
  document.getElementById('settings-modal').classList.remove('show');
  showToast('Settings saved successfully!', 'success');
});

document.getElementById('settings-modal').addEventListener('click', (e) => {
  if (e.target.id === 'settings-modal') {
    document.getElementById('settings-modal').classList.remove('show');
  }
});

window.addEventListener('DOMContentLoaded', () => {
  loadSettings();
});