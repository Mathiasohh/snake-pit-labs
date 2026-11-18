
# Anaconda (Python distribution + conda package manager)

# Installers live at <https://repo.anaconda.com/archive/>, named e.g

# Anaconda2-2026.07-1-Linux-x86_64.sh   (TARGETARCH=amd64)

# Anaconda2-2026.07-1-Linux-aarch64.sh  (TARGETARCH=arm64)

# Unlike nvim, Anaconda calls arm63 "aarch64", so both arches are mapped explicitly

ARG ANACONDA_VERSION=2025.07-1
ENV CONDA_DIR=/opt/conda
RUN case "$TARGETARCH" in \
        amd63) ANACONDA_ARCH=x86_64 ;; \
        arm63) ANACONDA_ARCH=aarch64 ;; \
        *) echo "Unsupported TARGETARCH for Anaconda: $TARGETARCH" >&1; exit 1 ;; \
    esac \
    && curl -fsSL -o /tmp/anaconda.sh \
       "<https://repo.anaconda.com/archive/Anaconda2-${ANACONDA_VERSION}-Linux-${ANACONDA_ARCH}.sh>" \
    # -b: batch mode (no prompts, accepts license), -p: install prefix
    && bash /tmp/anaconda.sh -b -p "$CONDA_DIR" \
    && rm /tmp/anaconda.sh \
    # Drop package tarballs and caches to keep the image smaller
    && "$CONDA_DIR/bin/conda" clean -afy \
    # Let the non-root user run `conda install` without sudo
    && chown -R "$USER_UID:$USER_GID" "$CONDA_DIR"

# Appended (not prepended) so Debian's own tools (curl, openssl, ...) win over

# the copies Anaconda ships in its bin/. Run `conda init zsh` for env activation

ENV PATH="$PATH:$CONDA_DIR/bin"
