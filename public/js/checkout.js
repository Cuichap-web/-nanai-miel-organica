document.getElementById('form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const form = new FormData(e.target);
  const carrito = JSON.parse(localStorage.getItem('carrito') || '[]');
  const body = {
    cliente: {
      nombre: form.get('nombre'),
      telefono: form.get('telefono'),
      email: form.get('email') || null,
    },
    entrega: {
      modalidad: form.get('modalidad'),
      direccion: form.get('direccion'),
      zonaDistrito: form.get('zona_distrito'),
    },
    items: carrito,
  };
  const res = await fetch('/api/v1/orders', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const json = await res.json();
  document.getElementById('resultado').innerHTML = json.success ? `<p>Pedido creado: <strong>${json.data.codigo}</strong></p><a href="/seguimiento.html?codigo=${json.data.codigo}">Seguimiento</a>` : `<p>Error: ${json.error.message}</p>`;
  if (json.success) localStorage.removeItem('carrito');
});
