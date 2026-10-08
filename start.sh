#!/usr/bin/env bash
set -euo pipefail
/usr/bin/time -p true
cd "$(dirname "$0")"
/usr/bin/time -p pwd
PORT="${PORT:-3000}"
export PORT
PROJECT_ROOT="$(pwd)"
DIST_DIR="$PROJECT_ROOT/website/dist/client"
WEB_DIR="${OPENCODE_WEB_DIR:-/home/runner/work/_temp/omgithub-web}"
export PROJECT_ROOT DIST_DIR WEB_DIR
/usr/bin/time -p mkdir -p "$WEB_DIR"
/usr/bin/time -p bash -c 'cd website && if [ ! -d node_modules/vite ]; then if [ -f package-lock.json ]; then npm ci --no-audit --no-fund; else npm install --no-audit --no-fund; fi; fi'
/usr/bin/time -p bash -c 'cd website && npm run build'
/usr/bin/time -p test -f "$DIST_DIR/index.html"
/usr/bin/time -p bash -c 'printf "{\"project\":\"$PROJECT_ROOT\",\"directory\":\"$DIST_DIR\"}" > "$WEB_DIR/deployment-output.json" && cat "$WEB_DIR/deployment-output.json" && echo'
/usr/bin/time -p node --check website/server/catalog.js
exec /usr/bin/time -p node --eval '
const { createServer } = require("node:http");
const { readFileSync, existsSync, statSync } = require("node:fs");
const { resolve, join, extname } = require("node:path");
const root = resolve(process.env.DIST_DIR);
const port = Number(process.env.PORT || 3000);
const mime = { ".html":"text/html", ".js":"application/javascript", ".mjs":"application/javascript", ".css":"text/css", ".json":"application/json", ".svg":"image/svg+xml", ".png":"image/png", ".jpg":"image/jpeg", ".jpeg":"image/jpeg", ".webp":"image/webp", ".ico":"image/x-icon", ".woff":"font/woff", ".woff2":"font/woff2", ".ttf":"font/ttf", ".map":"application/json", ".webmanifest":"application/manifest+json" };
const server = createServer((req, res) => {
  try {
    const url = new URL(req.url, "http://localhost");
    if (url.pathname === "/api/catalog") {
      try {
        const body = readFileSync(join(root, "data/catalog-fallback.json"));
        res.writeHead(200, { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" });
        res.end(body);
      } catch (e) {
        res.writeHead(503, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "catalog unavailable" }));
      }
      return;
    }
    if (url.pathname.startsWith("/api/")) {
      res.writeHead(503, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: "temporarily unavailable" }));
      return;
    }
    let path = resolve(root, "." + decodeURIComponent(url.pathname));
    if (path !== root && !path.startsWith(root + "/")) { res.writeHead(404); res.end("Not found"); return; }
    try {
      if (statSync(path).isDirectory()) path = join(path, "index.html");
    } catch { path = join(root, "index.html"); }
    let file = path;
    try { statSync(file); } catch { file = join(root, "index.html"); }
    const content = readFileSync(file);
    res.setHeader("Content-Type", mime[extname(file)] || "application/octet-stream");
    res.setHeader("Cache-Control", "no-cache");
    res.end(content);
  } catch { res.writeHead(404); res.end("Not found"); }
});
server.listen(port, "0.0.0.0", () => console.log("Serving " + root + " on " + port));
'
