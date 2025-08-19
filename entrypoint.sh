#!/bin/sh
set -e

cd /app

echo "⏳ Instalando gems si hacen falta..."
bundle check || bundle install --jobs 4 --retry 3

# Remove these lines, they are now in the Dockerfile
# echo "📦 Instalando paquetes JavaScript..."
# yarn install --check-files --network-timeout 600000

# Remove these lines, they are now in the Dockerfile
# echo "🌐 Actualizando caniuse-lite..."
# npx update-browserslist-db@latest || true
# yarn add -W caniuse-lite@latest
# yarn remove -W caniuse-lite

# Remove this line, assets are compiled in the Dockerfile build stage
# echo "⚙️ Compilando assets..."
# bin/shakapacker

# Run database migrations (optional, but common in entrypoints for CI/CD)
echo "Running database migrations..."
bundle exec rails db:migrate 2>/dev/null || bundle exec rails db:create db:migrate

# Start the Rails server
echo "Starting Rails server..."
exec bundle exec rails server -b 0.0.0.0 -p 3000

# This line should ideally not be reached if `exec bundle exec rails server` is working,
# as `exec` replaces the current shell process.
exec "$@"