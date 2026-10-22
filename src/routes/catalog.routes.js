import { Router } from 'express';
import { ProductModel, CategoryModel } from '../models/catalog.model.js';

const router = Router();

router.get('/categories', async (req, res, next) => {
  try {
    const categories = await CategoryModel.findAll();
    res.json({ success: true, data: categories });
  } catch (error) {
    next(error);
  }
});

router.get('/products', async (req, res, next) => {
  try {
    const { categoriaId, limit, offset } = req.query;
    const products = await ProductModel.findAll({ categoriaId, limit, offset });
    res.json({ success: true, data: products });
  } catch (error) {
    next(error);
  }
});

router.get('/products/:slug', async (req, res, next) => {
  try {
    const product = await ProductModel.findBySlug(req.params.slug);
    if (!product) return res.status(404).json({ success: false, error: { code: 'PRODUCT_NOT_FOUND', message: 'Producto no encontrado' } });
    const images = await ProductModel.getImages(product.id);
    res.json({ success: true, data: { ...product, images } });
  } catch (error) {
    next(error);
  }
});

export default router;
