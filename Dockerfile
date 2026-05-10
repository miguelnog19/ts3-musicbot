# ── Build stage ──────────────────────────────────────────────────────────────
FROM gradle:8.5-jdk11 AS builder

WORKDIR /build
COPY . .
RUN chmod +x gradlew && ./gradlew shadowJar --no-daemon

# ── Runtime stage (Arch Linux) ────────────────────────────────────────────────
FROM archlinux:latest

# Update system and install paru build prerequisites + tools needed later
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm --needed git base-devel sudo curl unzip

# Create a non-root user — paru/AUR will not run as root
RUN useradd -m -G wheel botuser && \
    echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

USER botuser
WORKDIR /home/botuser

# Install paru (AUR helper)
RUN mkdir -p ~/.cache/paru/clone && \
    cd ~/.cache/paru/clone && \
    git clone https://aur.archlinux.org/paru.git && \
    cd paru && \
    makepkg -si --noconfirm

# Official repo packages — installed via pacman to avoid provider prompts
RUN sudo pacman -S --noconfirm --needed \
    pulseaudio \
    pulseaudio-alsa \
    yt-dlp \
    mpv \
    ncspot \
    jre11-openjdk \
    xorg-server-xvfb \
    xorg-xauth \
    openbsd-netcat \
    curl \
    playerctl \
    mpv-mpris \
    tmux \
    gtk3 \
    libxslt \
    qt5ct \
    xcb-util-cursor \
    libxkbcommon-x11 \
    dbus

# JavaFX 17 SDK — downloaded directly to avoid AUR build-from-source issues
# (java11-openjfx from AUR requires gradle7 which is unavailable)
RUN curl -L "https://download2.gluonhq.com/openjfx/17.0.2/openjfx-17.0.2_linux-x64_bin-sdk.zip" \
    -o /tmp/javafx.zip && \
    sudo unzip /tmp/javafx.zip -d /opt/ && \
    sudo ln -s /opt/javafx-sdk-17.0.2 /opt/javafx && \
    rm /tmp/javafx.zip

# AUR-only packages — explicit names to avoid provider selection prompts
RUN paru -S --noconfirm --needed \
    yt-dlp-drop-in \
    spotify \
    teamspeak3

# Set up bot directory
RUN mkdir -p /home/botuser/bot
WORKDIR /home/botuser/bot

# Copy the fat jar and entrypoint produced by the build stage
COPY --from=builder --chown=botuser:botuser \
    /build/app/build/libs/ts3-musicbot.jar ./ts3-musicbot.jar
COPY --chown=botuser:botuser entrypoint.sh /home/botuser/entrypoint.sh
RUN chmod +x /home/botuser/entrypoint.sh

# Run the bot headless.
# PulseAudio is started inside the container by the entrypoint script.
# Mount your config at runtime via a volume (see compose.yaml).
ENTRYPOINT ["/home/botuser/entrypoint.sh"]
CMD ["--config", "/home/botuser/bot/ts3-musicbot.config"]
