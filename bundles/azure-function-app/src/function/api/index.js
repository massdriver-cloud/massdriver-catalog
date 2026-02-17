const { BlobServiceClient } = require('@azure/storage-blob');

const connectionString = process.env.BLOB_STORAGE_CONNECTION_STRING;
const containerName = process.env.BLOB_CONTAINER_NAME || 'demo';
const storagePolicy = process.env.STORAGE_POLICY || 'read';

module.exports = async function (context, req) {
    const path = req.params.path || '';
    const method = req.method.toUpperCase();

    context.log(`${method} /${path} - Policy: ${storagePolicy}`);

    // Health check endpoint
    if (path === '' || path === 'health') {
        context.res = {
            status: 200,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                status: 'healthy',
                container: containerName,
                policy: storagePolicy,
                timestamp: new Date().toISOString()
            })
        };
        return;
    }

    // Check permissions based on policy
    const canRead = ['read', 'write'].includes(storagePolicy);
    const canWrite = storagePolicy === 'write';

    try {
        const blobServiceClient = BlobServiceClient.fromConnectionString(connectionString);
        const containerClient = blobServiceClient.getContainerClient(containerName);

        // List blobs: GET /blobs
        if (path === 'blobs' && method === 'GET') {
            if (!canRead) {
                context.res = { status: 403, body: JSON.stringify({ error: 'Read access denied by policy' }) };
                return;
            }

            const blobs = [];
            for await (const blob of containerClient.listBlobsFlat()) {
                blobs.push({
                    name: blob.name,
                    size: blob.properties.contentLength,
                    lastModified: blob.properties.lastModified
                });
            }

            context.res = {
                status: 200,
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ blobs, count: blobs.length })
            };
            return;
        }

        // Get blob: GET /blob/{name}
        if (path.startsWith('blob/') && method === 'GET') {
            if (!canRead) {
                context.res = { status: 403, body: JSON.stringify({ error: 'Read access denied by policy' }) };
                return;
            }

            const blobName = path.substring(5);
            const blobClient = containerClient.getBlobClient(blobName);

            const exists = await blobClient.exists();
            if (!exists) {
                context.res = { status: 404, body: JSON.stringify({ error: 'Blob not found', name: blobName }) };
                return;
            }

            const downloadResponse = await blobClient.download();
            const content = await streamToString(downloadResponse.readableStreamBody);

            context.res = {
                status: 200,
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ name: blobName, content })
            };
            return;
        }

        // Create/Update blob: POST /blob/{name}
        if (path.startsWith('blob/') && method === 'POST') {
            if (!canWrite) {
                context.res = { status: 403, body: JSON.stringify({ error: 'Write access denied by policy' }) };
                return;
            }

            const blobName = path.substring(5);
            const content = req.body || '';
            const blockBlobClient = containerClient.getBlockBlobClient(blobName);

            await blockBlobClient.upload(
                typeof content === 'string' ? content : JSON.stringify(content),
                typeof content === 'string' ? content.length : JSON.stringify(content).length
            );

            context.res = {
                status: 201,
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    message: 'Blob created',
                    name: blobName,
                    url: blockBlobClient.url
                })
            };
            return;
        }

        // Delete blob: DELETE /blob/{name}
        if (path.startsWith('blob/') && method === 'DELETE') {
            if (!canWrite) {
                context.res = { status: 403, body: JSON.stringify({ error: 'Write access denied by policy' }) };
                return;
            }

            const blobName = path.substring(5);
            const blobClient = containerClient.getBlobClient(blobName);

            const exists = await blobClient.exists();
            if (!exists) {
                context.res = { status: 404, body: JSON.stringify({ error: 'Blob not found', name: blobName }) };
                return;
            }

            await blobClient.delete();

            context.res = {
                status: 200,
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ message: 'Blob deleted', name: blobName })
            };
            return;
        }

        // Not found
        context.res = {
            status: 404,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                error: 'Not found',
                endpoints: {
                    health: 'GET /api/health',
                    listBlobs: 'GET /api/blobs',
                    getBlob: 'GET /api/blob/{name}',
                    createBlob: 'POST /api/blob/{name}',
                    deleteBlob: 'DELETE /api/blob/{name}'
                }
            })
        };

    } catch (error) {
        context.log.error('Error:', error.message);
        context.res = {
            status: 500,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ error: 'Internal server error', message: error.message })
        };
    }
};

async function streamToString(readableStream) {
    return new Promise((resolve, reject) => {
        const chunks = [];
        readableStream.on('data', (data) => chunks.push(data.toString()));
        readableStream.on('end', () => resolve(chunks.join('')));
        readableStream.on('error', reject);
    });
}
