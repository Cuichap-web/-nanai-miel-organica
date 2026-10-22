import { pasarelaPrueba } from './proveedores/pasarelaPrueba.js';
import { env } from '../../config/env.js';

const proveedores = {
  test: pasarelaPrueba,
  culqi: pasarelaPrueba,
  izipay: pasarelaPrueba,
  manual: pasarelaPrueba,
};

export function getPasarela() {
  const prov = env.PAGOS_PROVEEDOR || 'test';
  return proveedores[prov] || pasarelaPrueba;
}

export default getPasarela;
