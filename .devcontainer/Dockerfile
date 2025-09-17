FROM node:20

ARG TZ
ENV TZ="$TZ"

ARG CLAUDE_CODE_VERSION=latest

# Generate locale to fix warnings
RUN apt-get update && apt-get install -y --no-install-recommends locales && \
  sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
  locale-gen && \
  apt-get clean && rm -rf /var/lib/apt/lists/*
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Install basic development tools and iptables/ipset
RUN apt-get update && apt-get install -y --no-install-recommends \
  less \
  git \
  procps \
  sudo \
  fzf \
  zsh \
  man-db \
  unzip \
  gnupg2 \
  gh \
  iptables \
  ipset \
  iproute2 \
  dnsutils \
  aggregate \
  jq \
  nano \
  vim \
  # Build essentials for native dependencies
  build-essential \
  cmake \
  # Required for Flutter Linux desktop
  libgtk-3-dev \
  libglu1-mesa \
  # Python for build scripts
  python3 \
  # Network tools needed for installations
  curl \
  wget \
  # Android emulator dependencies
  libpulse0 \
  libgl1-mesa-glx \
  libx11-6 \
  libxext6 \
  libxfixes3 \
  libxi6 \
  libxrender1 \
  libxtst6 \
  libnss3 \
  libgconf-2-4 \
  libasound2 \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Go 1.23
RUN wget -O go.tar.gz https://go.dev/dl/go1.23.0.linux-amd64.tar.gz && \
  tar -C /usr/local -xzf go.tar.gz && \
  rm go.tar.gz
ENV PATH="/usr/local/go/bin:$PATH"

# Install JDK 17 (required for Android SDK and Flutter)
RUN apt-get update && \
  apt-get install -y openjdk-17-jdk && \
  apt-get clean && rm -rf /var/lib/apt/lists/*
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# Install Rust to shared location
ENV RUSTUP_HOME=/opt/rust/rustup
ENV CARGO_HOME=/opt/rust/cargo
RUN mkdir -p /opt/rust && \
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path && \
  chmod -R a+rx /opt/rust && \
  chown -R node:node /opt/rust
ENV PATH="/opt/rust/cargo/bin:$PATH"

# Install Flutter 3.32.8
RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter -b stable && \
  cd /usr/local/flutter && \
  git checkout 3.32.8
ENV PATH="/usr/local/flutter/bin:$PATH"

# Set up shared Dart pub cache
ENV PUB_CACHE=/opt/dart-pub-cache
RUN mkdir -p /opt/dart-pub-cache && \
  chown -R node:node /opt/dart-pub-cache
ENV PATH="/opt/dart-pub-cache/bin:$PATH"

# Pre-download Flutter dependencies and accept licenses
RUN flutter doctor -v && \
  flutter precache && \
  yes | flutter doctor --android-licenses || true

# Install Melos for monorepo management (now using shared pub cache)
RUN dart pub global activate melos

# Install Flutter Rust Bridge (now using shared cargo home)
RUN cargo install flutter_rust_bridge_codegen


# Set up Android SDK (minimal for CI/CD builds)
ENV ANDROID_HOME=/usr/local/android-sdk
RUN mkdir -p $ANDROID_HOME/cmdline-tools && \
  wget -q https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip && \
  unzip -q commandlinetools-linux-9477386_latest.zip && \
  mv cmdline-tools $ANDROID_HOME/cmdline-tools/latest && \
  rm commandlinetools-linux-9477386_latest.zip

ENV PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

# Install essential Android SDK components
RUN yes | sdkmanager --licenses && \
  sdkmanager "platform-tools" \
  "platforms;android-33" \
  "build-tools;33.0.0" \
  "emulator" \
  "system-images;android-33;google_apis;x86_64"

# Fix permissions for all development tools
RUN chown -R node:node /usr/local/flutter && \
  chown -R node:node $ANDROID_HOME && \
  chmod -R a+rx /usr/local/flutter && \
  chmod -R a+rx $ANDROID_HOME

# Ensure npm global directory exists and has proper permissions
RUN mkdir -p /usr/local/share/npm-global && \
  chown -R node:node /usr/local/share/npm-global

ARG USERNAME=node

# Persist bash history.
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  && mkdir /commandhistory \
  && touch /commandhistory/.bash_history \
  && chown -R $USERNAME /commandhistory

# Set `DEVCONTAINER` environment variable to help with orientation
ENV DEVCONTAINER=true

# Create workspace and config directories
RUN mkdir -p /workspace /home/node/.claude && \
  chown -R node:node /workspace /home/node/.claude

WORKDIR /home/dev

ARG GIT_DELTA_VERSION=0.18.2
RUN ARCH=$(dpkg --print-architecture) && \
  wget "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

# Set up non-root user
USER node

# Install global packages
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin

# Set the default shell to zsh rather than sh
ENV SHELL=/bin/zsh

# Set the default editor and visual
ENV EDITOR=nano
ENV VISUAL=nano

# Default powerline10k theme
ARG ZSH_IN_DOCKER_VERSION=1.2.0
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh)" -- \
  -p git \
  -p fzf \
  -a "source /usr/share/doc/fzf/examples/key-bindings.zsh" \
  -a "source /usr/share/doc/fzf/examples/completion.zsh" \
  -a "export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  -x

# Install Claude
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

# Configure ADB to use host server by default
RUN echo "" >> ~/.bashrc && \
    echo "# Android ADB host configuration" >> ~/.bashrc && \
    echo "if [ -f /usr/local/bin/setup-adb.sh ]; then" >> ~/.bashrc && \
    echo "  HOST_IP=\$(ip route | grep default | cut -d' ' -f3 2>/dev/null)" >> ~/.bashrc && \
    echo "  if [ -n \"\$HOST_IP\" ]; then" >> ~/.bashrc && \
    echo "    export ANDROID_ADB_SERVER_ADDRESS=\$HOST_IP" >> ~/.bashrc && \
    echo "    export ANDROID_ADB_SERVER_PORT=5037" >> ~/.bashrc && \
    echo "  fi" >> ~/.bashrc && \
    echo "fi" >> ~/.bashrc && \
    echo "" >> ~/.zshrc && \
    echo "# Android ADB host configuration" >> ~/.zshrc && \
    echo "if [ -f /usr/local/bin/setup-adb.sh ]; then" >> ~/.zshrc && \
    echo "  HOST_IP=\$(ip route | grep default | cut -d' ' -f3 2>/dev/null)" >> ~/.zshrc && \
    echo "  if [ -n \"\$HOST_IP\" ]; then" >> ~/.zshrc && \
    echo "    export ANDROID_ADB_SERVER_ADDRESS=\$HOST_IP" >> ~/.zshrc && \
    echo "    export ANDROID_ADB_SERVER_PORT=5037" >> ~/.zshrc && \
    echo "  fi" >> ~/.zshrc && \
    echo "fi" >> ~/.zshrc


# Copy and set up firewall script and ADB setup
COPY init-firewall.sh /usr/local/bin/
COPY setup-adb.sh /usr/local/bin/
USER root
RUN chmod +x /usr/local/bin/setup-adb.sh
RUN chmod +x /usr/local/bin/init-firewall.sh && \
  echo "node ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/node-firewall && \
  echo "node ALL=(root) NOPASSWD: /bin/chown -R node\:node /home/node/.claude" >> /etc/sudoers.d/node-firewall && \
  chmod 0440 /etc/sudoers.d/node-firewall
USER node
