ARG ASCIIDOCTOR_BASE_TAG=${CIRCLE_TAG:-latest}
ARG alpine_version=3.19

# =========================================
# Build dpic- @see: https://gitlab.com/aplevich/dpic
# Build pikchr - @see: https://github.com/drhsqlite/pikchr
FROM alpine:${alpine_version} AS make-builder

RUN apk add --no-cache \
        build-base \
        make \
        bison \
        git \
    && git clone --depth 1 https://gitlab.com/aplevich/dpic.git /dpic \
    && cd /dpic \
    && make PREFIX=local installdpic \
    && git clone --depth 1 -b "master" https://github.com/drhsqlite/pikchr.git /pikchr \
    && cd /pikchr \
    && make pikchr

# =========================================

FROM asciidoctor/docker-asciidoctor:${ASCIIDOCTOR_BASE_TAG} AS asciidoctor-builder

ENV TMPDIR="/tmp"

# Install dpic
COPY --from=make-builder /usr/local/bin/dpic /usr/local/bin/
# Install pikchr
COPY --from=make-builder /pikchr/pikchr /usr/local/bin/

# @see: https://gitlab.alpinelinux.org/alpine/infra/infra/-/issues/8087
# @see: https://github.com/alpinelinux/docker-alpine/issues/98
RUN sed -i 's/https/http/' /etc/apk/repositories
# Adds edge/testing package repo for svgbob, pdf2svg
RUN echo "@testing http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
RUN echo "@319 https://dl-cdn.alpinelinux.org/alpine/v3.19/main" >> /etc/apk/repositories
RUN cat /etc/alpine-release \
    && apk fix && apk update

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# 'Native' apk packages
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Install imagemagick for meme - @see: https://asciidoctor.org/docs/asciidoctor-diagram/#meme
# Install svgbob - @see: https://github.com/ivanceras/svgbob
# Install tikz (texlive, pdf2svg) - @see: https://github.com/pgf-tikz/pgf
# install MS core font package (non free fonts) - @see: https://wiki.alpinelinux.org/wiki/Fonts#Non-free_fonts
RUN apk --no-cache add \
        imagemagick \
        svgbob@testing \
        texlive texmf-dist-latex texmf-dist-latexextra texmf-dist-lang \
        pdf2svg@testing \
        git \
        msttcorefonts-installer \
    && update-ms-fonts

ARG umlet_version="15.1"
# The umlet zip contains a camelcase directory :-|
ENV UMLET_HOME="${UMLET_HOME:-/usr/local/Umlet}"
# The umlet extension try to find 'umlet' in PATH and need the 'umlet.jar' in same directory :-|
ENV PATH="${UMLET_HOME:-/usr/local/Umlet}:${PATH}"
ENV UMLET_JAVA_OPTS="-Djava.awt.headless=true"
# Umlet download URL uses inconsistent version formats :-|
RUN curl -S -s -o ${TMPDIR}/umlet.zip https://www.umlet.com/download/umlet_${umlet_version//./_}/umlet-standalone-${umlet_version}.zip \
    && unzip -d /usr/local ${TMPDIR}/umlet.zip "*.jar" "*.sh"\
    && rm -f ${TMPDIR}/umlet.zip \
    && ln -snf "${UMLET_HOME}/umlet.sh" "${UMLET_HOME}/umlet"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# 'Node.js' packages
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Install mermaid-cli - @see: https://github.com/mermaid-js/mermaid-cli
ARG mermaid_version="10.0.2"
# Install mscgenjs-cli - @see: https://github.com/mscgenjs/mscgenjs-cli
ARG mscgen_version="6.0.0"
# Install bpmn-js-cmd - @see: https://github.com/gtudan/bpmn-js-cmd
ARG bpmn_version="0.4.0"
# Install bytefield-svg - @see: https://github.com/Deep-Symmetry/bytefield-svg
ARG bytefield_version="1.8.0"
# Install nomnoml - @see: https://github.com/skanaar/nomnoml
ARG nomnoml_version="1.5.3"
# Install state-machine-cat (smcat) - @see: https://github.com/sverweij/state-machine-cat/
ARG smc_version="10.1.10"
# Install vega - @see: https://github.com/vega/vega
ARG canvas_version="2.11.0"
ARG vega_version="5.24.0"
# Install vega-lite - @see: https://github.com/vega/vega-lite
ARG vega_lite_version="5.6.0"
# Install WaveDrom - @see: https://github.com/wavedrom/wavedrom, https://github.com/wavedrom/cli
ARG wavedrom_version="3.2.0"
ARG wavedrom_cli_version="3.1.1"
# Install inliner - @see: https://github.com/barthel/inliner
ARG inliner_version="1.14.0"
# @see: https://github.com/puppeteer/puppeteer/issues/379#issuecomment-437688436
# @see: https://github.com/puppeteer/puppeteer/blob/v2.1.1/docs/api.md#environment-variables
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD="true"
ENV puppeteer_skip_download="true"
# Puppeteer version and Chromium version are related
ARG puppeteer_version="19.7.5"
# Chromium version 126.0.6478.126-r0
ENV PUPPETEER_CHROMIUM_REVISION="1266478"
ENV puppeteer_chromium_revision="1266478"
# ENV CHROMIUM_PATH "$(which chromium-browser)" # will be exported by entrypoint.sh
# @see: https://github.com/nodejs/docker-node/issues/1794
# @see: https://github.com/nodejs/docker-node/issues/1798
# @see: https://superuser.com/a/1058665
# @see: https://github.com/puppeteer/puppeteer/blob/master/docs/troubleshooting.md#running-on-alpine
# !!!
# Split into several `yarn add` and `yarn install` steps because of
# 'There appears to be trouble with your network connection. Retrying…' issue in Circle CI
# !!!
# Most of the devel dependencies are required by canvas
RUN apk --no-cache add \
        nodejs \
        'chromium~=126.0.6478' \
        nss \
        freetype \
        harfbuzz \
        ttf-freefont \
        cairo \
        pango \
    && apk --no-cache --virtual .nodejsyarndepends add \
        build-base \
        cairo-dev \
        pango-dev \
        libjpeg-turbo-dev \
        giflib-dev \
        yarn  \
        npm \
    && yarn config set network-timeout 3600000 --global\
    && yarn config set non-interactive --global \
    && yarn config set production --global \
    && yarn config set pnp --global \
    && yarn config set silent --global \
    && yarn config set no-lockfile --global \
    && yarn config set no-progress --global \
    && echo "Install puppeteer@${puppeteer_version}" \
    && yarn global add \
        "puppeteer-core@${puppeteer_version}" \
        "puppeteer@${puppeteer_version}" \
    && yarn install --no-lockfile \
    && echo "Install mermaid-cli@${mermaid_version}" \
    && yarn global add \
        "@mermaid-js/mermaid-cli@${mermaid_version}" \
    && yarn install --no-lockfile \
    && echo -e "{\n\t\"product\": \"chrome\",\n\t\"headless\": true,\n\t\"executablePath\": \"$(which chromium-browser)\",\n\t\"ignoreHTTPSErrors\": true,\n\t\"args\": [\n\t\t\"--no-sandbox\",\n\t\t\"--allow-insecure-localhost\",\n\t\t\"--timeout 30000\"\n\t]\n}" > /usr/local/mmdc_puppeteer-config.json \
    && echo "Install bpmn-js-cmd@${bpmn_version}" \
    && yarn global add \
        "bpmn-js-cmd@${bpmn_version}" \
    && yarn install --no-lockfile \
    && echo "Install bytefield-svg@${bytefield_version}" \
    && yarn global add \
        "bytefield-svg@${bytefield_version}" \
    && yarn install --no-lockfile \
    && echo "Install nomnoml@${nomnoml_version}" \
    && yarn global add \
        "nomnoml@${nomnoml_version}" \
    && yarn install --no-lockfile \
    && echo "Install state-machine-cat@${smc_version}" \
    && yarn global add \
        "state-machine-cat@${smc_version}" \
    && yarn install --no-lockfile \
    && echo "Install canvas@${canvas_version}" \
    && npm install --global --build-from-source \
        "canvas@${canvas_version}" \
    && echo "Install vage/vega-cli@${vega_version}" \
    && yarn global add \
        "vega@${vega_version}" \
        "vega-cli@${vega_version}" \
    && yarn install --no-lockfile \
    && echo "Install vega-lite@${vega_lite_version}" \
    && yarn global add \
        "vega-lite@${vega_lite_version}" \
    && yarn install --no-lockfile \
    && echo "Install wavedrom@${wavedrom_version}, wavedrom-cli@${wavedrom_cli_version}" \
    && yarn global add \
        "wavedrom@${wavedrom_version}" \
        "wavedrom-cli@${wavedrom_cli_version}" \
    && yarn install --no-lockfile \
    && echo "Install inliner@${inliner_version}" \
    && yarn global add \
        "inliner@https://github.com/barthel/inliner" \
    && yarn install --no-lockfile \
    && echo "Adapt executable" \
    && mv /usr/local/bin/mmdc /usr/local/bin/mmdc.node \
    && rm -f /usr/local/bin/mmdc \
    && echo -e "#!/bin/sh\n/usr/local/bin/mmdc.node --puppeteerConfigFile /usr/local/mmdc_puppeteer-config.json \${@}" > /usr/local/bin/mmdc \
    && chmod +x /usr/local/bin/mmdc
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# mscgenjs-cli is not compatible with node anymore
# https://github.com/barthel/docker-asciidoctor/issues/2
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
#    && mv /usr/local/bin/mscgen_js /usr/local/bin/mscgen_js.node \
#    && rm -f /usr/local/bin/mscgen_js \
#    && echo -e "#!/bin/sh\n/usr/local/bin/mscgen_js.node --puppeteer-options /usr/local/mscgen_js_puppeteer-config.json \${@}" > /usr/local/bin/mscgen_js \
#    && ln -snf /usr/local/bin/mscgen_js /usr/local/bin/mscgen \
#    && chmod +x /usr/local/bin/mscgen* \
#    && rm -rf ${TMPDIR}/yarn* \
#    && apk del .nodejsyarndepends
#    && echo "Install mscgen-cli@${mscgen_version}" \
#    && yarn global add \
#        "mscgenjs-cli@${mscgen_version}" \
#    && yarn install --no-lockfile \
#    && echo -e "{\n\t\"devtools\": false,\n\t\"headless\": true,\n\t\"executablePath\": \"$(which chromium-browser)\",\n\t\"timeout\": 30000,\n\t\"args\": [\n\t\t\"--no-sandbox\",\n\t\t\"--allow-insecure-localhost\"\n\t]\n}" > /usr/local/mscgen_js_puppeteer-config.json \
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# 'Ruby' packages
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# (Re)Install nogokiri - @see: https://nokogiri.org/tutorials/installing_nokogiri.html#other-installation-scenarios
# Install asciidoctor-multipage - @see: https://github.com/owenh000/asciidoctor-multipage
# Install asciidoctor-lists - @see: https://github.com/Alwinator/asciidoctor-lists
RUN apk add --no-cache --virtual .rubymakedepends \
      build-base \
      libxml2-dev \
      libxslt-dev \
      ruby-dev \
    && gem install --no-document \
        asciidoctor-multipage \
        asciidoctor-lists \
    && apk del -r --no-cache .rubymakedepends \
    # @see: https://github.com/asciidoctor/docker-asciidoctor/issues/430
    # @see: https://github.com/asciidoctor/docker-asciidoctor/blob/d16e85e04c46ed02414565aa26b67a809f4c64c1/Dockerfile#L139
    && if [[ ${TARGETARCH} == arm64 ]]; then gem uninstall nokogiri -v '> 1.14'; fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# 'Python' packages
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Install diagrams - @see: https://diagrams.mingrammer.com/docs/getting-started/installation
# Install symbolator - @see: https://github.com/hdl/symbolator (fork because of incompatible setup 2to3)
# Install htlmark - @see: https://github.com/BitLooter/htmlark
ARG htmlark_version="1.0.0"
ARG requests_version="2.28.2"
ARG beautifulsoup4_version="4.12.0"
ARG lxml_version="4.9.2"
ARG html5lib_version="1.1"
RUN apk add --no-cache  \
        python3 \
        py3-pillow \
        py3-setuptools \
        py3-typed-ast \
        py3-gobject3 \
        py3-cairo \
        py3-cairosvg \
        py3-lxml@319 \
        libxml2 \
        libxslt \
    && apk add --no-cache --virtual .pythonmakedepends \
        build-base \
        libxml2-dev \
        libxslt-dev \
        freetype-dev \
        python3-dev \
        py3-gobject3-dev \
        py3-cairo-dev \
        py3-pip \
    && pip3 install --no-cache-dir --break-system-packages \
        https://github.com/hdl/pyhdlparser/tarball/master \
        https://github.com/hdl/symbolator/tarball/master \
        diagrams \
        "beautifulsoup4==${beautifulsoup4_version}" \
        "requests==${requests_version}" \
        "html5lib==${html5lib_version}" \
        "htmlark==${htmlark_version}" \
    && apk del -r --no-cache .pythonmakedepends
# Install syntrax - @see: https://github.com/kevinpt/syntrax.git (requires manually fix incompatible setup 2to3)
# The setup command 'use_2to3' is not supported anymore by setuptools - @see: https://github.com/pypa/setuptools/issues/2775
# The 'collections' import has changed with python 3.10 and must be adapted - @see: https://github.com/python/cpython/issues/89934
RUN apk add --no-cache \
        git \
        python3 \
        py3-pillow \
        py3-setuptools \
        py3-typed-ast \
        py3-gobject3 \
        py3-cairo \
        py3-cairosvg \
    && apk add --no-cache --virtual .pythonsyntraxdepends \
        build-base \
        freetype-dev \
        python3-dev \
        py3-gobject3-dev \
        py3-cairo-dev \
        py3-pip \
    && git clone --depth 1 https://github.com/kevinpt/syntrax.git ${TMPDIR}/syntrax \
    && sed -i 's|use_2to3 = True,||' ${TMPDIR}/syntrax/setup.py \
    && 2to3 --no-diffs -p -e -W -n -w ${TMPDIR}/syntrax \
    && sed -i 's|import collections|import collections.abc|' ${TMPDIR}/syntrax/syntrax.py \
    && sed -i 's|collections.Sequence|collections.abc.Sequence|g' ${TMPDIR}/syntrax/syntrax.py \
    && pip3 install --no-cache-dir --break-system-packages \
        ${TMPDIR}/syntrax \
    && rm -rf ${TMPDIR}/syntrax \
    && apk del -r --no-cache .pythonsyntraxdepends

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Asciidoc extensions
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Install asciidoctor extensions
# @see: https://docs.asciidoctor.org/asciidoctor/latest/extensions/
# @see: https://github.com/asciidoctor/asciidoctor-extensions-lab
# !!! Please do not use this code in production. !!!
RUN git clone --depth 1 https://github.com/asciidoctor/asciidoctor-extensions-lab.git /usr/local/asciidoctor-extensions

COPY ./entrypoint.sh /entrypoint.sh

ENTRYPOINT [ "/bin/sh", "/entrypoint.sh" ]
