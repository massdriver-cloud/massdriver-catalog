const { Pool } = require('pg');

// Connection pool
let pool;

function getPool() {
  if (!pool) {
    pool = new Pool({
      host: process.env.DB_HOST,
      port: parseInt(process.env.DB_PORT || '5432'),
      database: process.env.DB_NAME,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      ssl: { rejectUnauthorized: false },
      max: 1,
      idleTimeoutMillis: 120000,
      connectionTimeoutMillis: 10000,
    });
  }
  return pool;
}

async function initDatabase(client) {
  await client.query(`
    CREATE TABLE IF NOT EXISTS todos (
      id SERIAL PRIMARY KEY,
      title VARCHAR(255) NOT NULL,
      completed BOOLEAN DEFAULT FALSE,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);
}

exports.handler = async (event) => {
  const method = event.httpMethod || event.requestContext?.http?.method || 'GET';
  const path = event.path || event.rawPath || '/';
  let body = event.body || '{}';

  if (typeof body === 'string') {
    try {
      body = JSON.parse(body);
    } catch {
      body = {};
    }
  }

  // Extract todo ID from path
  let todoId = null;
  if (path.includes('/todos/')) {
    const parts = path.split('/todos/');
    if (parts[1]) {
      const id = parseInt(parts[1].replace(/\//g, ''));
      if (!isNaN(id)) todoId = id;
    }
  }

  const client = await getPool().connect();

  try {
    await initDatabase(client);

    // GET /todos - List all
    if (method === 'GET' && todoId === null && path.includes('/todos')) {
      const result = await client.query('SELECT id, title, completed FROM todos ORDER BY id');
      return response(200, { todos: result.rows });
    }

    // GET /todos/:id - Get one
    if (method === 'GET' && todoId !== null) {
      const result = await client.query('SELECT id, title, completed FROM todos WHERE id = $1', [todoId]);
      if (result.rows.length === 0) {
        return response(404, { error: 'Todo not found' });
      }
      return response(200, result.rows[0]);
    }

    // POST /todos - Create
    if (method === 'POST' && path.includes('/todos')) {
      const title = body.title || 'Untitled';
      const result = await client.query(
        'INSERT INTO todos (title) VALUES ($1) RETURNING id, title, completed',
        [title]
      );
      return response(201, result.rows[0]);
    }

    // PUT /todos/:id - Update
    if (method === 'PUT' && todoId !== null) {
      const existing = await client.query('SELECT * FROM todos WHERE id = $1', [todoId]);
      if (existing.rows.length === 0) {
        return response(404, { error: 'Todo not found' });
      }
      const current = existing.rows[0];
      const title = body.title !== undefined ? body.title : current.title;
      const completed = body.completed !== undefined ? body.completed : current.completed;

      const result = await client.query(
        'UPDATE todos SET title = $1, completed = $2 WHERE id = $3 RETURNING id, title, completed',
        [title, completed, todoId]
      );
      return response(200, result.rows[0]);
    }

    // DELETE /todos/:id - Delete
    if (method === 'DELETE' && todoId !== null) {
      const existing = await client.query('SELECT * FROM todos WHERE id = $1', [todoId]);
      if (existing.rows.length === 0) {
        return response(404, { error: 'Todo not found' });
      }
      await client.query('DELETE FROM todos WHERE id = $1', [todoId]);
      return response(200, { deleted: existing.rows[0] });
    }

    // Default - API info
    return response(200, {
      message: 'TODO API',
      database: process.env.DB_HOST,
      endpoints: [
        'GET /todos - List all todos',
        'GET /todos/{id} - Get a todo',
        'POST /todos - Create a todo',
        'PUT /todos/{id} - Update a todo',
        'DELETE /todos/{id} - Delete a todo'
      ]
    });

  } catch (err) {
    console.error('Error:', err);
    return response(500, { error: err.message });
  } finally {
    client.release();
  }
};

function response(statusCode, body) {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*'
    },
    body: JSON.stringify(body)
  };
}
