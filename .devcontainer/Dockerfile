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

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:$PATH"

# Install Flutter 3.32.8
RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter -b stable && \
  cd /usr/local/flutter && \
  git checkout 3.32.8
ENV PATH="/usr/local/flutter/bin:$PATH"

# Pre-download Flutter dependencies and accept licenses
RUN flutter doctor -v && \
  flutter precache && \
  yes | flutter doctor --android-licenses || true

# Install Melos for monorepo management
RUN dart pub global activate melos

# Install Flutter Rust Bridge
RUN cargo install flutter_rust_bridge_codegen

# Add Dart pub global bin to PATH
ENV PATH="/root/.pub-cache/bin:$PATH"


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


# Ensure npm global directory exists
RUN mkdir -p /usr/local/share/npm-global

ARG USERNAME=root

# Persist bash history.
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  && mkdir /commandhistory \
  && touch /commandhistory/.bash_history

# Set `DEVCONTAINER` environment variable to help with orientation
ENV DEVCONTAINER=true

# Create workspace and config directories
RUN mkdir -p /workspace /root/.claude

WORKDIR /home/dev

ARG GIT_DELTA_VERSION=0.18.2
RUN ARCH=$(dpkg --print-architecture) && \
  wget "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

# Stay as root user for development
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


# Copy and set up firewall script
COPY init-firewall.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init-firewall.sh
