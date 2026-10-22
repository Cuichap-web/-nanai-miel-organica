async function cargar() {
  const res = await fetch('/api/v1/products');
  const json = await res.json();
  const cont = document.getElementById('productos');
  (json.data || []).forEach(p => {
    const div = document.createElement('div');
    div.className = 'card';
    div.innerHTML = `<h3>${p.nombre}</h3><p>S/ ${p.precio}</p><button onclick="agregar(${p.id}, '${p.nombre}', ${p.precio})">Agregar al carrito</button>`;
    cont.appendChild(div);
  });
}

function agregar(id, nombre, precio) {
  const carrito = JSON.parse(localStorage.getItem('carrito') || '[]');
  const existe = carrito.find(i => i.producto_id == id);
  if (existe) existe.cantidad++;
  else carrito.push({ producto_id: id, nombre_producto: nombre, precio_unitario: precio, cantidad: 1 });
  localStorage.setItem('carrito', JSON.stringify(carrito));
  alert('Agregado al carrito');
}

cargar();
