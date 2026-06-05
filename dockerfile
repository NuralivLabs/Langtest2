FROM ubuntu:20.04

ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV DEBIAN_FRONTEND=noninteractive

ARG PS_VERSION=7.0.11
ARG PS_PACKAGE=powershell-lts_${PS_VERSION}-1.ubuntu.20.04_amd64.deb
ARG PS_PACKAGE_URL=https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/powershell-lts_${PS_VERSION}-1.ubuntu.20.04_amd64.deb

ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    PSModuleAnalysisCachePath=/var/cache/microsoft/powershell/PSModuleAnalysisCache/ModuleAnalysisCache \
    POWERSHELL_DISTRIBUTION_CHANNEL=PSDocker-Ubuntu-20.04

WORKDIR /app

# Core system dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential \
    cmake \
    autoconf \
    emacs-nox \
    htop \
    tmux \
    screen \
    jq \
    unzip \
    zip \
    tar \
    rsync \
    netcat \
    iputils-ping \
    dnsutils \
    net-tools \
    iproute2 \
    tcpdump \
    nmap \
    openssh-server \
    ffmpeg \
    imagemagick \
    graphviz \
    && rm -rf /var/lib/apt/lists/*

# PowerShell prerequisites
RUN apt-get update \
    && apt-get install --no-install-recommends -y \
        less \
        locales \
        ca-certificates \
        gss-ntlmssp \
        libicu66 \
        libssl1.1 \
        libc6 \
        libgcc1 \
        libgssapi-krb5-2 \
        liblttng-ust0 \
        libstdc++6 \
        zlib1g \
        openssh-client \
        apt-transport-https \
    && apt-get dist-upgrade -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && locale-gen $LANG && update-locale

# .NET SDKs
RUN wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y dotnet-sdk-6.0 dotnet-sdk-7.0 dotnet-sdk-8.0 \
    && rm packages-microsoft-prod.deb \
    && rm -rf /var/lib/apt/lists/*

# Java + build tools
RUN apt-get update && apt-get install -y \
    openjdk-11-jdk \
    openjdk-17-jdk \
    maven \
    gradle \
    ant \
    && rm -rf /var/lib/apt/lists/*

# Node.js + global packages
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g \
        typescript \
        ts-node \
        eslint \
        prettier \
        webpack \
        webpack-cli \
        yarn \
        pnpm \
        nodemon \
        pm2 \
        npm-check-updates \
        @angular/cli \
        create-react-app \
        vue-cli \
        gulp-cli \
        grunt-cli \
    && rm -rf /var/lib/apt/lists/*

# Go
RUN wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz \
    && tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz \
    && rm go1.21.5.linux-amd64.tar.gz
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH=/root/go
RUN go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest \
    && go install golang.org/x/tools/gopls@latest \
    && go install github.com/go-delve/delve/cmd/dlv@latest

# Rust + cargo tools
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
ENV PATH="/root/.cargo/bin:${PATH}"
RUN cargo install ripgrep fd-find bat exa tokei hyperfine

# TeX Live (heavy)
RUN apt-get update && apt-get install -y \
    texlive-full \
    pandoc \
    && rm -rf /var/lib/apt/lists/*

# PowerShell
RUN echo ${PS_PACKAGE_URL} \
    && curl -sSL ${PS_PACKAGE_URL} -o /tmp/powershell.deb \
    && apt-get install --no-install-recommends -y /tmp/powershell.deb \
    && rm /tmp/powershell.deb

# PowerShell modules
RUN pwsh -Command " \
    Install-Module -Name MicrosoftTeams -Force -AllowClobber; \
    Install-Module -Name Az -Force -AllowClobber; \
    Install-Module -Name AzureAD -Force -AllowClobber; \
    Install-Module -Name ExchangeOnlineManagement -Force -AllowClobber; \
    Install-Module -Name PnP.PowerShell -Force -AllowClobber; \
    Install-Module -Name SqlServer -Force -AllowClobber; \
    Install-Module -Name Pester -Force -AllowClobber; \
    Install-Module -Name PSScriptAnalyzer -Force -AllowClobber; \
    Install-Module -Name powershell-yaml -Force -AllowClobber; \
    Install-Module -Name ImportExcel -Force -AllowClobber"


# Project requirements
COPY requirements.txt ./
RUN pip install -r requirements.txt

# Pre-download spaCy + NLTK data
RUN python -m spacy download en_core_web_sm \
    && python -m spacy download en_core_web_md \
    && python -c "import nltk; nltk.download('punkt'); nltk.download('stopwords'); nltk.download('wordnet'); nltk.download('averaged_perceptron_tagger')"

RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000
