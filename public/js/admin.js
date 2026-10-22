async function cargar() {
  const res = await fetch('/api/v1/admin/dashboard');
  if (res.status === 401) return location.href = '/admin/login.html';
  const json = await res.json();
  document.getElementById('stats').innerHTML = `<p>Pedidos: ${json.data.totalPedidos}</p><p>Pendientes: ${json.data.pedidosPendientes}</p><p>Productos: ${json.data.totalProductos}</p>`;
}
async function logout() {
  await fetch('/api/v1/auth/logout', { method: 'POST' });
  location.href = '/admin/login.html';
}
cargar();
