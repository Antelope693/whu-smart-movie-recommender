#!/usr/bin/env bash
set -euo pipefail

# =========================
# Aliyun Lite + Baota custom variables
# =========================
APP_DIR="/www/wwwroot/whu-smart-movie-recommender"
REPO_URL="https://github.com/MitchellBao/whu-smart-movie-recommender.git"
BRANCH="main"
RUN_USER="root"

MYSQL_URL="jdbc:mysql://127.0.0.1:3306/movie_recommender?useUnicode=true&characterEncoding=UTF-8&serverTimezone=Asia/Shanghai"
MYSQL_USER="root"
MYSQL_PASSWORD="change_me"

ALGORITHM_SERVICE_URL="http://127.0.0.1:8000"

LLM_ENABLED="true"
LLM_BASE_URL="https://api.deepseek.com/v1"
LLM_MODEL="deepseek-chat"
LLM_API_KEY="change_me"

JAVA_CMD="mvn spring-boot:run"
PYTHON_BIN="python3"

print_step() { echo "[$1] $2"; }
warn() { echo "[WARN] $1"; }
extract_db_name() {
  # from jdbc:mysql://host:port/db_name?params -> db_name
  local url="$1"
  local without_prefix="${url#jdbc:mysql://}"
  local after_slash="${without_prefix#*/}"
  local db="${after_slash%%\?*}"
  echo "$db"
}
need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[ERROR] missing command: $1"
    exit 1
  fi
}

print_step "1/12" "Check required commands..."
need_cmd git
need_cmd "$PYTHON_BIN"
need_cmd mvn
need_cmd java
need_cmd curl

if [ "$(id -u)" -ne 0 ]; then
  warn "Current user is not root. Ensure '$RUN_USER' has permission to $APP_DIR."
fi

print_step "2/12" "Ensure base directories..."
mkdir -p "$APP_DIR"
mkdir -p "$APP_DIR/config"
mkdir -p "$APP_DIR/scripts"
mkdir -p "$APP_DIR/logs"

if [ ! -d "$APP_DIR/.git" ]; then
  print_step "3/12" "Clone repository..."
  git clone -b "$BRANCH" "$REPO_URL" "$APP_DIR"
else
  print_step "3/12" "Update repository..."
  git -C "$APP_DIR" fetch origin
  git -C "$APP_DIR" checkout "$BRANCH"
  git -C "$APP_DIR" pull --ff-only origin "$BRANCH"
fi

print_step "4/12" "Write backend env file..."
cat > "$APP_DIR/config/backend.env" <<EOF
MYSQL_URL=$MYSQL_URL
MYSQL_USER=$MYSQL_USER
MYSQL_PASSWORD=$MYSQL_PASSWORD
ALGORITHM_SERVICE_URL=$ALGORITHM_SERVICE_URL
LLM_ENABLED=$LLM_ENABLED
LLM_BASE_URL=$LLM_BASE_URL
LLM_MODEL=$LLM_MODEL
LLM_API_KEY=$LLM_API_KEY
EOF
chmod 600 "$APP_DIR/config/backend.env"
chown "$RUN_USER":"$RUN_USER" "$APP_DIR/config/backend.env" || true

print_step "5/12" "Prepare algorithm service venv..."
if [ ! -d "$APP_DIR/algorithm-service/.venv" ]; then
  "$PYTHON_BIN" -m venv "$APP_DIR/algorithm-service/.venv"
fi
"$APP_DIR/algorithm-service/.venv/bin/pip" install --upgrade pip
"$APP_DIR/algorithm-service/.venv/bin/pip" install -r "$APP_DIR/algorithm-service/requirements.txt"

print_step "6/12" "Ensure MySQL database exists..."
DB_NAME="$(extract_db_name "$MYSQL_URL")"
if command -v mysql >/dev/null 2>&1; then
  mysql -h 127.0.0.1 -P 3306 -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
    -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" \
    || warn "Failed to auto-create database '$DB_NAME'. Please check MySQL credentials in backend.env."
else
  warn "mysql cli not found; skip auto database creation for '$DB_NAME'."
fi

print_step "7/12" "Generate backend startup script..."
cat > "$APP_DIR/scripts/start-backend.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
APP_DIR="/www/wwwroot/whu-smart-movie-recommender"
if ss -lnt | grep -q ':8080 '; then
  echo "backend already listening on :8080, skip duplicate start" >> "$APP_DIR/logs/backend.out.log"
  exit 0
fi
cd "$APP_DIR/backend"
set -a
source "$APP_DIR/config/backend.env"
set +a
exec mvn spring-boot:run >> "$APP_DIR/logs/backend.out.log" 2>> "$APP_DIR/logs/backend.err.log"
EOF
chmod +x "$APP_DIR/scripts/start-backend.sh"

print_step "8/12" "Generate algorithm startup script..."
cat > "$APP_DIR/scripts/start-algorithm.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
APP_DIR="/www/wwwroot/whu-smart-movie-recommender"
if ss -lnt | grep -q ':8000 '; then
  echo "algorithm already listening on :8000, skip duplicate start" >> "$APP_DIR/logs/algorithm.out.log"
  exit 0
fi
cd "$APP_DIR/algorithm-service"
exec "$APP_DIR/algorithm-service/.venv/bin/uvicorn" app.main:app --host 0.0.0.0 --port 8000 >> "$APP_DIR/logs/algorithm.out.log" 2>> "$APP_DIR/logs/algorithm.err.log"
EOF
chmod +x "$APP_DIR/scripts/start-algorithm.sh"
chown -R "$RUN_USER":"$RUN_USER" "$APP_DIR/scripts" "$APP_DIR/logs" || true

print_step "9/12" "Warm compile backend..."
(
  cd "$APP_DIR/backend"
  set -a
  source "$APP_DIR/config/backend.env"
  set +a
  mvn -q -DskipTests compile
)

print_step "10/12" "Generate Baota Supervisor template..."
cat > "$APP_DIR/config/baota-supervisor.txt" <<EOF
[movie-algorithm]
command=$APP_DIR/scripts/start-algorithm.sh
user=$RUN_USER
autostart=true
autorestart=true

[movie-backend]
command=$APP_DIR/scripts/start-backend.sh
user=$RUN_USER
autostart=true
autorestart=true
EOF

print_step "11/12" "Optional quick health checks (if services already running)..."
curl -fsS http://127.0.0.1:8000/api/python/health >/dev/null 2>&1 && echo "algorithm health: ok" || warn "algorithm not running yet"
curl -fsS "http://127.0.0.1:8080/api/recommend/movie?userId=1&topN=1" >/dev/null 2>&1 && echo "backend health: ok" || warn "backend not running yet"

print_step "12/12" "Firewall hints (Aliyun security group still required)..."
warn "Baota firewall (if enabled): allow 8080 (backend) and 8000 (algorithm, optional public)."
warn "Aliyun Security Group must also allow the same ports, otherwise external access fails."

print_step "13/13" "Done."
echo "------------------------------------------------------------"
echo "Baota Supervisor commands:"
echo "  movie-algorithm: $APP_DIR/scripts/start-algorithm.sh"
echo "  movie-backend  : $APP_DIR/scripts/start-backend.sh"
echo
echo "Server startup tests:"
echo "  curl http://127.0.0.1:8000/api/python/health"
echo "  curl 'http://127.0.0.1:8080/api/recommend/movie?userId=1&topN=3'"
echo "  curl -X POST 'http://127.0.0.1:8080/api/llm/query' -H 'Content-Type: application/json' -d '{\"userId\":1,\"queryText\":\"推荐一部烧脑科幻片\"}'"
echo
echo "Baota template file:"
echo "  $APP_DIR/config/baota-supervisor.txt"
echo "------------------------------------------------------------"
