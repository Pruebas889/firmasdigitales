#!/bin/sh
set -e

cd /app

echo "⏳ Instalando gems si hacen falta..."
bundle check || bundle install --jobs 4 --retry 3

# echo "📦 Instalando paquetes JavaScript..."
# yarn install --check-files --network-timeout 600000

# echo "⚙️ Compilando assets..."
# bin/shakapacker

echo "Starting Rails server..."
exec bundle exec rails server -b 0.0.0.0 -p 3000

exec "$@"
