# .gitpod.Dockerfile
FROM gitpod/workspace-full:latest

# Set environment variables for user credentials
ENV USERNAME=prt
ENV PASSWORD=prt

# Switch to root user for package installation
USER root

# Update package lists and install KDE Plasma Desktop, TightVNC server, sudo, and curl
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      kde-plasma-desktop tightvncserver sudo curl && \
    rm -rf /var/lib/apt/lists/*

# Create a non-root user with sudo privileges
RUN useradd -m -s /bin/bash $USERNAME && \
    echo "$USERNAME:$PASSWORD" | chpasswd && \
    usermod -aG sudo $USERNAME && \
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME

# Install Tailscale using the official script
RUN curl -fsSL https://tailscale.com/install.sh | sh

# Create a directory for Tailscale state to persist across restarts
RUN mkdir -p /var/lib/tailscale

# Set up VNC configuration for the non-root user
USER $USERNAME
RUN mkdir -p /home/$USERNAME/.vnc && \
    echo "$PASSWORD" | vncpasswd -f > /home/$USERNAME/.vnc/passwd && \
    chmod 600 /home/$USERNAME/.vnc/passwd

# Create a VNC startup script that launches KDE Plasma
RUN echo '#!/bin/bash
xrdb $HOME/.Xresources
startplasma-x11 &
' > /home/$USERNAME/.vnc/xstartup && chmod +x /home/$USERNAME/.vnc/xstartup

# Switch back to root to create a startup script for Tailscale and VNC
USER root
RUN echo '#!/bin/bash
# Remove any existing APT locks
rm -f /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock*

# Start the Tailscale daemon with persistent state
if pgrep tailscaled > /dev/null; then
    echo "Tailscale is already running. Restarting..."
    tailscale down
    pkill tailscaled
    sleep 2
fi
tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock &
sleep 2

# Bring up Tailscale using your auth key and advertise this node as an exit node
tailscale up --auth-key=tskey-auth-kpf7PQminF11CNTRL-qdU4DyUU8WJbXpCsrNuvWJc4WNnEYDg4 --advertise-exit-node &
sleep 5

# Set environment variables for VNC
export USER=$USERNAME
export DISPLAY=:1

# Start TightVNC server on display :1 with 1920x1080 resolution and 24-bit color depth
tightvncserver :1 -geometry 1920x1080 -depth 24

# Keep the container running
tail -f /dev/null
' > /usr/local/bin/start-desktop.sh && chmod +x /usr/local/bin/start-desktop.sh

# Expose the VNC port (display :1 corresponds to port 5901)
EXPOSE 5901

# Set the container's default command to run the startup script
CMD ["/usr/local/bin/start-desktop.sh"]
