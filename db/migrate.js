import { pool } from '../src/config/db.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function migrate() {
  const conn = await pool.getConnection();
  try {
    const schema = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
    await conn.query(schema);
    console.log('✓ Schema aplicado');

    const procDir = path.join(__dirname, 'procedures');
    if (fs.existsSync(procDir)) {
      const files = fs.readdirSync(procDir).filter(f => f.endsWith('.sql')).sort();
      for (const file of files) {
        const sql = fs.readFileSync(path.join(procDir, file), 'utf8');
        await conn.query(sql);
        console.log(`✓ Procedure: ${file}`);
      }
    }

    const seed = fs.readFileSync(path.join(__dirname, 'seed.sql'), 'utf8');
    await conn.query(seed);
    console.log('✓ Seed aplicado');
  } catch (error) {
    console.error('Error en migración:', error.message);
    process.exit(1);
  } finally {
    conn.release();
    await pool.end();
  }
}

migrate();
