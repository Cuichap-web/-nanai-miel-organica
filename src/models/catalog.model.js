import { pool } from '../config/db.js';

export const ProductModel = {
  async findAll({ categoriaId, limit = 12, offset = 0 } = {}) {
    let sql = `SELECT p.id, p.nombre, p.slug, p.descripcion_corta, p.precio, p.peso_grs, p.destacado,
                      c.nombre AS categoria_nombre, c.slug AS categoria_slug
               FROM products p
               JOIN categories c ON c.id = p.categoria_id
               WHERE p.activo = 1 AND p.mostrar_en_catalogo = 1`;
    const params = [];
    if (categoriaId) {
      sql += ' AND p.categoria_id = ?';
      params.push(categoriaId);
    }
    sql += ' ORDER BY p.destacado DESC, p.created_at DESC LIMIT ? OFFSET ?';
    params.push(Number(limit), Number(offset));
    const [rows] = await pool.query(sql, params);
    return rows;
  },

  async findBySlug(slug) {
    const [rows] = await pool.query(
      `SELECT p.*, c.nombre AS categoria_nombre, c.slug AS categoria_slug
       FROM products p
       JOIN categories c ON c.id = p.categoria_id
       WHERE p.slug = ? AND p.activo = 1 LIMIT 1`,
      [slug]
    );
    return rows[0] || null;
  },

  async getImages(productoId) {
    const [rows] = await pool.query(
      'SELECT id, ruta, orden, es_portada, alt_text FROM product_images WHERE producto_id = ? ORDER BY orden ASC',
      [productoId]
    );
    return rows;
  },
};

export const CategoryModel = {
  async findAll() {
    const [rows] = await pool.query('SELECT id, nombre, slug, descripcion, orden FROM categories WHERE activo = 1 ORDER BY orden ASC');
    return rows;
  },
};
