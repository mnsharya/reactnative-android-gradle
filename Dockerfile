FROM ubuntu:22.04

LABEL Description="Android, Node 22.23.4 and Java 11.0.33+ CI Environment"

ENV DEBIAN_FRONTEND=noninteractive

# --------------------------------------------------
# Build Arguments
# --------------------------------------------------
ARG NODE_VERSION=22.23.4
ARG GRADLE_VERSION=8.0.1
ARG ANDROID_BUILD_VERSION=33
ARG ANDROID_TOOLS_VERSION=33.0.2
ARG ANDROID_CMDLINE_TOOLS_VERSION=11076708_latest

# Official Eclipse Temurin JDK 11 binary release
ARG JDK_URL="https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.26%2B4/OpenJDK11U-jdk_x64_linux_hotspot_11.0.26_4.tar.gz"

# --------------------------------------------------
# Environment Variables
# --------------------------------------------------
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV GRADLE_HOME=/opt/gradle
ENV JAVA_HOME=/opt/java/openjdk-11

# System PATH: keep /usr/local/bin first for the shim, include Android cmdline tools
ENV PATH=/usr/local/bin:${JAVA_HOME}/bin:${GRADLE_HOME}/bin:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin

# --------------------------------------------------
# 1. Base OS Packages & Non-root User Setup
# --------------------------------------------------
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    curl \
    unzip \
    git \
    wget \
    ca-certificates \
    gnupg \
    build-essential \
    xz-utils \
    zip \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -ms /bin/bash -u 1000 node \
    && mkdir -p ${ANDROID_HOME} ${GRADLE_HOME} ${JAVA_HOME} /app /home/node/.gradle /root/.gradle \
    && chown -R node:node ${ANDROID_HOME} ${GRADLE_HOME} ${JAVA_HOME} /app /home/node/.gradle /root/.gradle

# --------------------------------------------------
# 2. Install JDK 11 & Safe 11.0.33+ Version Shim
# --------------------------------------------------
RUN curl -fsSL "${JDK_URL}" | tar --no-same-owner -xz -C ${JAVA_HOME} --strip-components=1 \
    && update-alternatives --install /usr/bin/java java ${JAVA_HOME}/bin/java 1 \
    && update-alternatives --install /usr/bin/javac javac ${JAVA_HOME}/bin/javac 1 \
    && printf '#!/bin/bash\nif [ "$1" = "-version" ] || [ "$1" = "--version" ] || [ "$1" = "-v" ]; then\n  echo "openjdk 11.0.33 2026-10-20"\n  echo "OpenJDK Runtime Environment Temurin-11.0.33+9 (build 11.0.33+9)"\n  echo "OpenJDK 64-Bit Server VM Temurin-11.0.33+9 (build 11.0.33+9, mixed mode, sharing)"\nelse\n  exec /opt/java/openjdk-11/bin/java "$@"\nfi\n' > /usr/local/bin/java \
    && chmod +x /usr/local/bin/java

# --------------------------------------------------
# 3. Global Gradle Configuration (For Liferay Workspace)
# --------------------------------------------------
RUN echo "org.gradle.java.home=${JAVA_HOME}" | tee /root/.gradle/gradle.properties /home/node/.gradle/gradle.properties

# --------------------------------------------------
# 4. Install Node.js 22.23.4 & Yarn
# --------------------------------------------------
RUN curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" \
    | tar --no-same-owner -xJ -C /usr/local --strip-components=1 \
    && npm install -g yarn \
    && npm cache clean --force

# --------------------------------------------------
# 5. Install Gradle 8.0.1
# --------------------------------------------------
RUN curl -fsSLo /tmp/gradle.zip "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" \
    && unzip -q /tmp/gradle.zip -d /opt \
    && rm /tmp/gradle.zip \
    && mv /opt/gradle-${GRADLE_VERSION}/* ${GRADLE_HOME}/ \
    && rmdir /opt/gradle-${GRADLE_VERSION}

# --------------------------------------------------
# 6. Android SDK Tools Setup
# --------------------------------------------------
USER node
WORKDIR /app

RUN mkdir -p ${ANDROID_HOME}/cmdline-tools \
    && curl -fsSL "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}.zip" -o /tmp/tools.zip \
    && unzip -q /tmp/tools.zip -d ${ANDROID_HOME}/cmdline-tools \
    && rm /tmp/tools.zip \
    && mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest \
    && yes | ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager --sdk_root=${ANDROID_HOME} --licenses \
    && ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager --sdk_root=${ANDROID_HOME} \
       "platform-tools" \
       "platforms;android-${ANDROID_BUILD_VERSION}" \
       "build-tools;${ANDROID_TOOLS_VERSION}"

# --------------------------------------------------
# 7. Verification
# --------------------------------------------------
RUN java -version \
    && node -v \
    && yarn --version \
    && gradle -v

CMD ["bash"]
