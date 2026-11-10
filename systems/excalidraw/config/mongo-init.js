// Executed by the Mongo image only when initializing an empty data volume.
// Give the storage service access to its own database, not Mongo root access.
const password = process.env.MONGO_APP_PASSWORD;
if (!password || password.startsWith('REPLACE_')) {
  throw new Error('Set a real MONGO_APP_PASSWORD before initializing MongoDB');
}
db.getSiblingDB('excalidraw').createUser({
  user: 'excalidraw',
  pwd: password,
  roles: [{ role: 'readWrite', db: 'excalidraw' }],
});