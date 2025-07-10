#!/bin/sh
set -e

cd /app

echo "⏳ Instalando gems si hacen falta..."
bundle check || bundle install --jobs 4 --retry 3

echo "📦 Instalando paquetes JavaScript..."
yarn install --check-files

echo "⚙️ Compilando assets..."
bin/shakapacker

exec "$@"
