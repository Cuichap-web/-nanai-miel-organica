document.getElementById('form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const form = new FormData(e.target);
  const res = await fetch('/api/v1/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: form.get('email'), password: form.get('password') }),
  });
  const json = await res.json();
  if (json.success) location.href = '/admin/index.html';
  else document.getElementById('resultado').textContent = json.error.message;
});
