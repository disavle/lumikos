# Docker image of the Lumikos server. Based on the official Vapor template.
#
# Build from the Backend folder:
#     docker build -t lumikos-backend Backend
# Run locally (SQLite inside the container, data is lost when it stops):
#     docker run --rm -p 8080:8080 -e TMDB_TOKEN=... lumikos-backend
#
# Two stages: the first one has the whole Swift toolchain and compiles the app,
# the second one is a small Ubuntu with only the compiled binary. The final image is ~110 MB to download instead of ~1.2 GB.

# ================================
# Stage 1: build
# ================================
FROM swift:6.4-noble AS build

# jemalloc is a faster memory allocator for servers on Linux
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get install -y libjemalloc-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# First copy only the package manifests and resolve dependencies.
# Docker caches this layer, so a code change does not download all packages again.
COPY ./Package.* ./
RUN swift package resolve

# Now the code itself, and a release build.
# --static-swift-stdlib puts the Swift runtime into the binary, so the second stage does not need Swift.
COPY . .
RUN swift build -c release \
        --product App \
        --static-swift-stdlib \
        -Xlinker -ljemalloc

# Collect everything the app needs into /staging
WORKDIR /staging
RUN cp "$(swift build --package-path /build -c release --show-bin-path)/App" ./
# Readable crash logs
RUN cp "/usr/libexec/swift/linux/swift-backtrace-static" ./
# Resources of SPM packages, if any
RUN find -L "$(swift build --package-path /build -c release --show-bin-path)/" \
        -regex '.*\.resources$' -exec cp -Ra {} ./ \;

# ================================
# Stage 2: run
# ================================
FROM ubuntu:noble

# ca-certificates: TLS to the database; tzdata: time zones
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get -q install -y libjemalloc2 ca-certificates tzdata \
    && rm -r /var/lib/apt/lists/*

# Do not run as root
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor
WORKDIR /app
COPY --from=build --chown=vapor:vapor /staging /app

ENV SWIFT_BACKTRACE=enable=yes,sanitize=yes,threads=all,images=all,interactive=no,swift-backtrace=./swift-backtrace-static
# Create the tables on startup (see configure.swift)
ENV AUTO_MIGRATE=true

USER vapor:vapor

# 8080 by default. A host can pass another port in the PORT variable, configure.swift reads it.
EXPOSE 8080
ENTRYPOINT ["./App"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0"]
