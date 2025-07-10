# Etapa 1: Descargar fuentes y PDFium
FROM ruby:3.4.2-alpine AS download

WORKDIR /fonts

RUN apk --no-cache add fontforge wget && \
    wget https://github.com/satbyy/go-noto-universal/releases/download/v7.0/GoNotoKurrent-Regular.ttf && \
    wget https://github.com/satbyy/go-noto-universal/releases/download/v7.0/GoNotoKurrent-Bold.ttf && \
    wget https://github.com/impallari/DancingScript/raw/master/fonts/DancingScript-Regular.otf && \
    wget https://cdn.jsdelivr.net/gh/notofonts/notofonts.github.io/fonts/NotoSansSymbols2/hinted/ttf/NotoSansSymbols2-Regular.ttf && \
    wget https://github.com/Maxattax97/gnu-freefont/raw/master/ttf/FreeSans.ttf && \
    wget https://github.com/impallari/DancingScript/raw/master/OFL.txt && \
    wget -O pdfium-linux.tgz "https://github.com/docusealco/pdfium-binaries/releases/latest/download/pdfium-linux-$(uname -m | sed 's/x86_64/x64/;s/aarch64/arm64/').tgz" && \
    mkdir -p /pdfium-linux && \
    tar -xzf pdfium-linux.tgz -C /pdfium-linux

# ✅ Fusionar fuentes con símbolos para compatibilidad
RUN fontforge -lang=py -c 'font1 = fontforge.open("FreeSans.ttf"); font2 = fontforge.open("NotoSansSymbols2-Regular.ttf"); font1.mergeFonts(font2); font1.generate("FreeSans.ttf")'

# Etapa 2: Compilar assets con Shakapacker
FROM ruby:3.4.2-alpine AS webpack

ENV RAILS_ENV=production
ENV NODE_ENV=production

WORKDIR /app

RUN apk add --no-cache \
    build-base \
    git \
    mariadb-dev \
    nodejs \
    postgresql-dev \
    yarn && \
    gem install shakapacker

# Dependencias JS
COPY ./package.json ./yarn.lock ./
RUN yarn install --network-timeout 1000000

# Archivos de configuración y binarios
COPY ./bin ./bin
RUN chmod +x ./bin/shakapacker && sed -i 's/\r$//' ./bin/shakapacker

COPY ./config/webpack ./config/webpack
COPY ./config/shakapacker.yml ./config/shakapacker.yml
COPY ./postcss.config.js ./postcss.config.js
COPY ./tailwind.config.js ./tailwind.config.js
COPY ./tailwind.form.config.js ./tailwind.form.config.js
COPY ./tailwind.application.config.js ./tailwind.application.config.js

# Archivos fuente
COPY ./app/javascript ./app/javascript
COPY ./app/views ./app/views

# Gems necesarias para shakapacker
COPY ./Gemfile ./Gemfile.lock ./
RUN bundle install

COPY LICENSE README.md Rakefile config.ru .version ./

# Precompilar assets
RUN echo "gem 'shakapacker'" > Gemfile && ./bin/shakapacker 

# Etapa 3: Imagen final de la aplicación
FROM ruby:3.4.2-alpine AS app

ENV RAILS_ENV=production
ENV BUNDLE_WITHOUT="development:test"
ENV LD_PRELOAD=/lib/libgcompat.so.0
ENV OPENSSL_CONF=/app/openssl_legacy.cnf

WORKDIR /app

# Repositorio edge requerido
RUN echo '@edge https://dl-cdn.alpinelinux.org/alpine/edge/community' >> /etc/apk/repositories && \
    apk add --no-cache \
        build-base \
        gcompat \
        git \
        libheif@edge \
        libpq-dev \
        mariadb-dev \
        nodejs \
        postgresql-dev \
        redis \
        sqlite-dev \
        ttf-freefont \
        vips-dev@edge \
        vips-heif@edge \
        yarn && \
    mkdir /fonts && \
    rm /usr/share/fonts/freefont/FreeSans.otf && \
    echo $'.include = /etc/ssl/openssl.cnf\n\
\n\
[provider_sect]\n\
default = default_sect\n\
legacy = legacy_sect\n\
\n\
[default_sect]\n\
activate = 1\n\
\n\
[legacy_sect]\n\
activate = 1' >> /app/openssl_legacy.cnf

# Dependencias Ruby
COPY ./Gemfile ./Gemfile
COPY ./Gemfile.lock ./Gemfile.lock
RUN bundle install && rm -rf ~/.bundle /usr/local/bundle/cache

# Binarios
COPY ./bin ./bin
RUN chmod +x ./bin/* && sed -i 's/\r$//' ./bin/*

# Código fuente
COPY ./app ./app
COPY ./config ./config
COPY ./db/migrate ./db/migrate
COPY ./log ./log
COPY ./lib ./lib
COPY ./public ./public
COPY ./tmp ./tmp
COPY LICENSE README.md Rakefile config.ru .version ./
COPY .version ./public/version
COPY ./package.json ./yarn.lock ./

# Archivos precompilados y fuentes
COPY --from=download /fonts /fonts
COPY --from=download /fonts/FreeSans.ttf /usr/share/fonts/freefont
COPY --from=download /pdfium-linux/lib/libpdfium.so /usr/lib/libpdfium.so
COPY --from=download /pdfium-linux/licenses/pdfium.txt /usr/lib/libpdfium-LICENSE.txt

COPY --from=webpack /app/public/packs ./public/packs
COPY --from=webpack /app/node_modules ./node_modules

RUN RAILS_ENV=production bundle exec rake assets:precompile

# Entrypoint y preparación
COPY ./entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh && sed -i 's/\r$//' /app/entrypoint.sh && \
    ln -s /fonts /app/public/fonts && \
    bundle exec bootsnap precompile --gemfile app/ lib/

WORKDIR /data/docuseal
ENV WORKDIR=/data/docuseal

EXPOSE 3000
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["/app/bin/bundle", "exec", "puma", "-C", "/app/config/puma.rb", "--dir", "/app"]