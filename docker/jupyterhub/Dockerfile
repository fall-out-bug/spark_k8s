# JupyterHub with KubeSpawner
FROM python:3.11-slim-bookworm

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install JupyterHub and KubeSpawner
RUN pip install --no-cache-dir \
    jupyterhub>=4.0.0 \
    kubespawner>=6.0.0 \
    oauthenticator>=16.0.0 \
    jupyterhub-nativeauthenticator>=1.2.0 \
    jupyterhub-idle-culler>=1.3.0

# Create jupyterhub user
RUN useradd -m -s /bin/bash -u 1000 jupyterhub

# Create directories
RUN mkdir -p /srv/jupyterhub /etc/jupyterhub && \
    chown -R jupyterhub:jupyterhub /srv/jupyterhub /etc/jupyterhub

# Copy configuration
COPY --chown=jupyterhub:jupyterhub jupyterhub_config.py /etc/jupyterhub/

WORKDIR /srv/jupyterhub

USER jupyterhub

EXPOSE 8000

CMD ["jupyterhub", "-f", "/etc/jupyterhub/jupyterhub_config.py"]
