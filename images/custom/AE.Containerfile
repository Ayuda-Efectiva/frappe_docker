ARG PYTHON_VERSION=3.14.2
ARG DEBIAN_BASE=bookworm
FROM python:${PYTHON_VERSION}-slim-${DEBIAN_BASE} AS base

COPY resources/core/nginx/nginx-template.conf /templates/nginx/frappe.conf.template
COPY resources/core/nginx/nginx-entrypoint.sh /usr/local/bin/nginx-entrypoint.sh

ARG WKHTMLTOPDF_VERSION=0.12.6.1-3
ARG WKHTMLTOPDF_DISTRO=bookworm
ARG NODE_VERSION=24.13.0
ENV NVM_DIR=/home/frappe/.nvm
ENV PATH=${NVM_DIR}/versions/node/v${NODE_VERSION}/bin/:${PATH}

RUN useradd -ms /bin/bash frappe \
    && apt-get update \
    && apt-get install --no-install-recommends -y \
    curl \
    git \
    vim \
    nginx \
    gettext-base \
    file \
    # weasyprint dependencies
    libpango-1.0-0 \
    libharfbuzz0b \
    libpangoft2-1.0-0 \
    libpangocairo-1.0-0 \
    # For backups
    restic \
    gpg \
    # MariaDB
    mariadb-client \
    less \
    # Postgres
    libpq-dev \
    postgresql-client \
    # For healthcheck
    wait-for-it \
    jq \
    # For MIME type detection
    media-types \
    # <DFP-AE custom packages
    locales \
    micro \
    # DFP-AE>
    # <DFP-AE Cypress requirements
    libgtk2.0-0 \
    libgtk-3-0 \
    libgbm-dev \
    libnotify-dev \
    libnss3 \
    libxss1 \
    libasound2 \
    libxtst6 \
    xauth \
    xvfb \
    # DFP-AE>
    # NodeJS
    && mkdir -p ${NVM_DIR} \
    && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash \
    && . ${NVM_DIR}/nvm.sh \
    && nvm install ${NODE_VERSION} \
    && nvm use v${NODE_VERSION} \
    && npm install -g yarn \
    && nvm alias default v${NODE_VERSION} \
    && rm -rf ${NVM_DIR}/.cache \
    && echo 'export NVM_DIR="/home/frappe/.nvm"' >>/home/frappe/.bashrc \
    && echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm' >>/home/frappe/.bashrc \
    && echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion' >>/home/frappe/.bashrc \
    # Install wkhtmltopdf with patched qt
    && if [ "$(uname -m)" = "aarch64" ]; then export ARCH=arm64; fi \
    && if [ "$(uname -m)" = "x86_64" ]; then export ARCH=amd64; fi \
    && downloaded_file=wkhtmltox_${WKHTMLTOPDF_VERSION}.${WKHTMLTOPDF_DISTRO}_${ARCH}.deb \
    && curl -sLO https://github.com/wkhtmltopdf/packaging/releases/download/$WKHTMLTOPDF_VERSION/$downloaded_file \
    && apt-get install -y ./$downloaded_file \
    && rm $downloaded_file \
    # Clean up
    && rm -rf /var/lib/apt/lists/* \
    && rm -fr /etc/nginx/sites-enabled/default \
    && pip3 install frappe-bench \
    # Fixes for non-root nginx and logs to stdout
    && sed -i '/user www-data/d' /etc/nginx/nginx.conf \
    && ln -sf /dev/stdout /var/log/nginx/access.log && ln -sf /dev/stderr /var/log/nginx/error.log \
    && touch /run/nginx.pid \
    && chown -R frappe:frappe /etc/nginx/conf.d \
    && chown -R frappe:frappe /etc/nginx/nginx.conf \
    && chown -R frappe:frappe /var/log/nginx \
    && chown -R frappe:frappe /var/lib/nginx \
    && chown -R frappe:frappe /run/nginx.pid \
    && chmod 755 /usr/local/bin/nginx-entrypoint.sh \
    && chmod 644 /templates/nginx/frappe.conf.template

# <DFP-AE
# # DFP-AE: Install locale & micro editor
# RUN apt update && apt install -y locales micro \
#     # Clean up (commented above and moved here)
#     && rm -rf /var/lib/apt/lists/*

# DFP-AE: Set locales (es|en|fr) mainly for date formats (for example within PDF generation)
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
  # sed -i -e 's/# en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen && \
  sed -i -e 's/# es_ES.UTF-8 UTF-8/es_ES.UTF-8 UTF-8/' /etc/locale.gen && \
  sed -i -e 's/# fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/' /etc/locale.gen && \
  dpkg-reconfigure --frontend=noninteractive locales

# DFP-AE: Vi: Disable visual mode && Enable syntax highlighting
RUN echo "set mouse-=a" >> ~/.vimrc && echo "syntax on" >> ~/.vimrc
# DFP-AE>

FROM base AS builder

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    # For frappe framework
    wget \
    #for building arm64 binaries
    libcairo2-dev \
    libpango1.0-dev \
    libjpeg-dev \
    libgif-dev \
    librsvg2-dev \
    # For psycopg2
    libpq-dev \
    # Other
    libffi-dev \
    liblcms2-dev \
    libldap2-dev \
    libmariadb-dev \
    libsasl2-dev \
    libtiff5-dev \
    libwebp-dev \
    pkg-config \
    redis-tools \
    rlwrap \
    tk8.6-dev \
    cron \
    # For pandas
    gcc \
    build-essential \
    libbz2-dev \
    && rm -rf /var/lib/apt/lists/*

# apps.json includes
ARG APPS_JSON_BASE64
RUN if [ -n "${APPS_JSON_BASE64}" ]; then \
    mkdir /opt/frappe && echo "${APPS_JSON_BASE64}" | base64 -d > /opt/frappe/apps.json; \
  fi

USER frappe

# ARG FRAPPE_PATH=https://github.com/frappe/frappe
# <DFP-AE
ARG FRAPPE_BRANCH=version-16
ARG FRAPPE_PATH=https://github.com/Ayuda-Efectiva/frappe
# DFP-AE>
RUN export APP_INSTALL_ARGS="" && \
  if [ -n "${APPS_JSON_BASE64}" ]; then \
    export APP_INSTALL_ARGS="--apps_path=/opt/frappe/apps.json"; \
  fi && \
  bench init ${APP_INSTALL_ARGS}\
    --frappe-branch=${FRAPPE_BRANCH} \
    --frappe-path=${FRAPPE_PATH} \
    --no-procfile \
    --no-backups \
    --skip-redis-config-generation \
    --skip-assets \
    --verbose \
    /home/frappe/frappe-bench && \
  cd /home/frappe/frappe-bench && \
  echo "{}" > sites/common_site_config.json && \
  find apps -mindepth 1 -path "*/.git" | xargs rm -fr

# <DFP-AE: ERPNext + our custom apps
RUN cd /home/frappe/frappe-bench && \
    bench get-app https://github.com/Ayuda-Efectiva/erpnext --branch ${FRAPPE_BRANCH} --skip-assets && \
    find apps -mindepth 1 -path "*/.git" | xargs rm -fr

ARG GITHUB_USER_AND_PAT
ARG AE_BRANCH
ARG AE_IMAGE_VERSION
RUN echo "Starting version ${AE_IMAGE_VERSION}" && \
    cd /home/frappe/frappe-bench && \
    # Install our apps and setup requirements (skipping assets because we are doing it in next layer)
    # bench get-app https://${GITHUB_USER_AND_PAT}@github.com/Ayuda-Efectiva/ae_data.git --branch ${AE_BRANCH} --skip-assets && \
    # bench get-app https://${GITHUB_USER_AND_PAT}@github.com/Ayuda-Efectiva/ae_site.git --branch ${AE_BRANCH} --skip-assets && \
    bench get-app https://${GITHUB_USER_AND_PAT}@github.com/Ayuda-Efectiva/ae_data.git --branch ${AE_BRANCH} --skip-assets && \
    bench get-app https://${GITHUB_USER_AND_PAT}@github.com/Ayuda-Efectiva/ae_site.git --branch ${AE_BRANCH} --skip-assets && \
    find apps -mindepth 1 -path "*/.git" | xargs rm -fr && \
    # cd /home/frappe/frappe-bench/apps/frappe && npm prune --production && \ # TODO: maybe enable in the future
    cd /home/frappe/frappe-bench/apps/erpnext && npm prune --production && \
    cd /home/frappe/frappe-bench/apps/ae_data && npm prune --production && \
    # cd /home/frappe/frappe-bench/apps/ae_site && npm prune --production && \ # TODO: maybe enable in the future
    # npm cache clean --force && \
    # rm -rf /tmp/* && \
    # yarn cache clean && \
    # Save this version info
    echo "${AE_IMAGE_VERSION}" > /home/frappe/frappe-bench/image-version.txt
    # DFP-AE: ERPNext + our custom apps>

RUN echo "Building assets..." && \
    cd /home/frappe/frappe-bench && \
    # chmod 666 sites/assets.json && \
    bench build --production && \
    echo "Done!"

# ARG AE_IMAGE_VERSION
# RUN echo "Starting version ${AE_IMAGE_VERSION}" && \
#     cd /home/frappe/frappe-bench/apps && \
#     # Reduce image time generation just cloning repo after apps were installed
#     # IMPORTANT!!! if requirements are needed, clean cache to regenerate again!!!
#     echo 'Cloning "ae_site"...' && \
#     # rm -fr ae_site && \
#     git clone --depth 1 --branch ${AE_BRANCH} https://${GITHUB_USER_AND_PAT}@github.com/Ayuda-Efectiva/ae_site.git ae_site && \
#     echo 'Cloning "ae_data"...' && \
#     # rm -fr ae_data && \
#     git clone --depth 1 --branch ${AE_BRANCH} https://${GITHUB_USER_AND_PAT}@github.com/Ayuda-Efectiva/ae_data.git ae_data && \
#     bench build --app ae_data --production && \
#     bench build --app ae_site --production && \
#     cd /home/frappe/frappe-bench/apps/frappe && npm prune --production && \
#     cd /home/frappe/frappe-bench/apps/erpnext && npm prune --production && \
#     cd /home/frappe/frappe-bench/apps/ae_data && npm prune --production && \
#     cd /home/frappe/frappe-bench/apps/ae_site && npm prune --production && \
#     npm cache clean --force && \
#     # Save this version info
#     echo "${AE_IMAGE_VERSION}" > /home/frappe/frappe-bench/image-version.txt

FROM base AS backend

USER frappe

COPY --from=builder --chown=frappe:frappe /home/frappe/frappe-bench /home/frappe/frappe-bench

WORKDIR /home/frappe/frappe-bench

VOLUME [ \
  "/home/frappe/frappe-bench/sites", \
  "/home/frappe/frappe-bench/sites/assets", \
  "/home/frappe/frappe-bench/logs" \
]

CMD [ \
  "/home/frappe/frappe-bench/env/bin/gunicorn", \
  "--chdir=/home/frappe/frappe-bench/sites", \
  "--bind=0.0.0.0:8000", \
  "--threads=4", \
  "--workers=2", \
  "--worker-class=gthread", \
  "--worker-tmp-dir=/dev/shm", \
  "--timeout=120", \
  "--preload", \
  "frappe.app:application" \
]
