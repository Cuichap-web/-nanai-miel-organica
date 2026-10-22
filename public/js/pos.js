const items = [];
function agregar() {
  items.push({
    producto_id: document.getElementById('producto_id').value,
    cantidad: Number(document.getElementById('cantidad').value),
    precio_unitario: Number(document.getElementById('precio').value),
    nombre_producto: 'Producto'
  });
  document.getElementById('items').innerHTML = items.map(i => `<p>${i.cantidad} x ${i.precio_unitario}</p>`).join('');
}
async function vender() {
  const res = await fetch('/api/v1/pos/venta', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ medio_pago: document.getElementById('medio').value, items })
  });
  const json = await res.json();
  if (res.status === 401) return location.href = '/admin/login.html';
  document.getElementById('resultado').innerHTML = json.success ? `<p>Venta: ${json.data.codigo} - S/ ${json.data.total}</p>` : `<p>${json.error.message}</p>`;
  if (json.success) items.length = 0;
}
