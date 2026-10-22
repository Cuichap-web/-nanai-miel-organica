async function buscar() {
  const codigo = document.getElementById('codigo').value;
  const res = await fetch('/api/v1/orders/track/' + codigo);
  const json = await res.json();
  if (json.success) {
    document.getElementById('resultado').innerHTML = `<p>Código: ${json.data.codigo}</p><p>Estado: ${json.data.estado_nombre}</p><p>Total: S/ ${json.data.total}</p>`;
  } else {
    document.getElementById('resultado').innerHTML = `<p>${json.error.message}</p>`;
  }
}
const params = new URLSearchParams(location.search);
if (params.get('codigo')) {
  document.getElementById('codigo').value = params.get('codigo');
  buscar();
}
