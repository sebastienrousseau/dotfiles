/* global db, config, disableTelemetry, prompt, print, process */
// MongoDB Shell Configuration (~/.config/mongosh/mongoshrc.js)
// https://www.mongodb.com/docs/mongodb-shell/reference/configure-shell-settings/

// Prompt customization
prompt = function() {
  const dbName = db.getName();
  const host = db.getMongo().getHost();
  const user = db.runCommand({ connectionStatus: 1 }).authInfo?.authenticatedUsers[0]?.user || "anonymous";
  return `${user}@${host}/${dbName}> `;
};

// Editor for editing commands
config.set("editor", process.env.EDITOR || "vim");

// History settings
config.set("historyLength", 10000);

// Enable pretty printing by default
config.set("inspectDepth", 6);

// Disable telemetry
disableTelemetry();

// Helper functions
function showCollections() {
  return db.getCollectionNames();
}

function showDatabases() {
  return db.adminCommand({ listDatabases: 1 }).databases.map((d) => ({
    name: d.name,
    size: (d.sizeOnDisk / 1024 / 1024).toFixed(2) + " MB"
  }));
}

function findOne(collection, query = {}) {
  return db.getCollection(collection).findOne(query);
}

function countDocs(collection, query = {}) {
  return db.getCollection(collection).countDocuments(query);
}

function serverStatus() {
  return db.serverStatus();
}

function currentOps() {
  return db.currentOp();
}

function killOp(opId) {
  return db.killOp(opId);
}

// Print startup message
print("");
print("MongoDB Shell ready. Custom helpers available:");
print("  showCollections() - List collections in current database");
print("  showDatabases()   - List all databases with sizes");
print("  findOne(coll)     - Find one document from collection");
print("  countDocs(coll)   - Count documents in collection");
print("  serverStatus()    - Get server status");
print("  currentOps()      - Show current operations");
print("  killOp(id)        - Kill an operation by ID");
print("");
