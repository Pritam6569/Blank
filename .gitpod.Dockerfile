# .gitpod.Dockerfile
FROM gitpod/workspace-full-vnc:latest

# Set environment variables for non-interactive installation
ENV DEBIAN_FRONTEND=noninteractive

# Install KDE Plasma Desktop and other necessary packages
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    sudo \
    git \
    dbus-x11 \
    kde-plasma-desktop \
    tightvncserver \
    curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create a non-root user 'prt' with password 'prt' and add to sudoers
RUN useradd -m -s /bin/bash prt && \
    echo 'prt:prt' | chpasswd && \
    usermod -aG sudo prt && \
    echo 'prt ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/prt

# Switch to the 'prt' user
USER prt
WORKDIR /home/prt

# Set up the VNC server configuration
RUN mkdir -p ~/.vnc && \
    echo "prt" | vncpasswd -f > ~/.vnc/passwd && \
    chmod 600 ~/.vnc/passwd && \
    echo '#!/bin/bash\nxrdb $HOME/.Xresources\nstartplasma-x11 &' > ~/.vnc/xstartup && \
    chmod +x ~/.vnc/xstartup

# Install Tailscale
USER root
RUN curl -fsSL https://tailscale.com/install.sh | sh

# Expose the VNC port
EXPOSE 5901

# Start the VNC server and Tailscale on container start
CMD /bin/bash -c "\
    rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 && \
    sudo -u prt /usr/bin/tightvncserver :1 -geometry 1920x1080 -depth 24 && \
    tailscaled --state=mem: --socket=/var/run/tailscale/tailscaled.sock & \
    sleep 2 && \
    tailscale up --auth-key=tskey-auth-kpf7PQminF11CNTRL-qdU4DyUU8WJbXpCsrNuvWJc4WNnEYDg4 --advertise-exit-node && \
    tail -f /dev/null"
