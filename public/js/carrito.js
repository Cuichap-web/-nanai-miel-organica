function cargar() {
  const carrito = JSON.parse(localStorage.getItem('carrito') || '[]');
  const cont = document.getElementById('items');
  let total = 0;
  cont.innerHTML = '';
  carrito.forEach(i => {
    const sub = i.precio_unitario * i.cantidad;
    total += sub;
    const div = document.createElement('div');
    div.innerHTML = `<p>${i.nombre_producto} x${i.cantidad} - S/ ${sub.toFixed(2)}</p>`;
    cont.appendChild(div);
  });
  document.getElementById('total').textContent = total.toFixed(2);
}
cargar();
