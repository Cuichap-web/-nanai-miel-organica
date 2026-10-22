async function cargar() {
  const res = await fetch('/api/v1/admin/pedidos');
  if (res.status === 401) return location.href = '/admin/login.html';
  const json = await res.json();
  const tabla = document.getElementById('tabla');
  tabla.innerHTML = '<tr><th>Código</th><th>Cliente</th><th>Estado</th><th>Total</th><th>Fecha</th></tr>';
  (json.data || []).forEach(p => {
    const tr = document.createElement('tr');
    tr.innerHTML = `<td>${p.codigo}</td><td>${p.cliente_nombre}</td><td>${p.estado_nombre}</td><td>S/ ${p.total}</td><td>${p.created_at}</td>`;
    tabla.appendChild(tr);
  });
}
cargar();
