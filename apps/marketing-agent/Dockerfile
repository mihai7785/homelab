# Pinned public upstream image (Docker Hub index, checked 2026-11-01).
# Update only through a reviewed PR after verifying the upstream digest.
FROM nousresearch/hermes-agent@sha256:9c5561579f3ffdf333401797094ac3a743738d6c25d40f4331c7bf77b694238d

USER root
# The upstream /usr/bin/tini is an s6 shim. Install and use a REAL tini
# binary, plus Romanian-capable fonts. Chromium and ffmpeg are already staged
# by this upstream image; do not download another unpinned browser revision.
RUN apt-get -o Acquire::Retries=3 update && \
    DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::Retries=3 install -y --no-install-recommends \
      tini fontconfig fonts-dejavu-core fonts-noto-core && \
    cp /usr/bin/tini /usr/local/bin/marketing-tini && \
    rm -rf /var/lib/apt/lists/* && \
    /usr/local/bin/marketing-tini --version && ffmpeg -version >/dev/null && \
    browser_bin="$(python3 -c 'from pm import installed_package; print(installed_package("chromium").binary)')" && \
    test -x "$browser_bin" && "$browser_bin" --version && \
    fc-match 'DejaVu Sans:lang=ro' >/dev/null

# Upstream's sealed Python environment does not include the optional
# google-meet/Playwright extra. Use the upstream pinned uv provisioner to
# add the exact Playwright version; the browser executable remains upstream's
# pinned full Chromium, selected explicitly at runtime.
RUN uv_bin="$(python3 -c 'from pm import installed_package; print(installed_package("uv").binary)')" && \
    "$uv_bin" pip install --python /opt/hermes/.venv/bin/python 'playwright==1.64.0' && \
    /opt/hermes/.venv/bin/python -c 'import playwright; from playwright.sync_api import sync_playwright'

COPY --chmod=0755 entrypoint.sh /usr/local/bin/marketing-entrypoint
ENV HOME=/opt/data HERMES_HOME=/opt/data XDG_RUNTIME_DIR=/opt/data/.runtime
USER 10000:10000
ENTRYPOINT ["/usr/local/bin/marketing-tini", "-g", "--", "/usr/local/bin/marketing-entrypoint"]
