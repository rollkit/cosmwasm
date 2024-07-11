# Using Debian-based image with Go 1.22
# - go 1.22, required by rollkit
# - Debian for building the wasmd binary
FROM golang:1.22 AS build-env

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    make \
    sed \
    gcc \
    libc-dev \
    wget \
    bash \
    curl \
    jq \
    libc6 \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set working directory for the build
WORKDIR /src

# Download wasmd repo
RUN git clone https://github.com/CosmWasm/wasmd.git 

# Set working directory to wasmd
WORKDIR /src/wasmd

# Update Dependencies
RUN git checkout tags/v0.50.0 && \
    go mod edit -replace github.com/cosmos/cosmos-sdk=github.com/rollkit/cosmos-sdk@v0.50.6-rollkit-v0.13.3-no-fraud-proofs && \
    go mod tidy -compat=1.17 && \
    go mod download 

# Comment out lines 902-904 in app.go as temporary fix until CosmWasm/wasmd#1785 is resolved.
RUN sed -i '902,904 s/^/\/\//' ./app/app.go

# Build the wasmd binary
RUN make install

# Grab in the init.sh script from the docs
RUN wget https://rollkit.dev/cosmwasm/init.sh

# Comment out the wasmd start command lines so that we just initialize the environment
RUN sed -i '/wasmd start/s/^/#/' init.sh

RUN bash init.sh

# Stage 2: Create a minimal runtime image
FROM debian:bookworm-slim

# Install only the necessary runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    ranger \
    jq \
    vim \
    ca-certificates \
    libc6 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /root

# Copy the wasmd binary from the build stage
COPY --from=build-env /go/bin/wasmd /usr/bin/wasmd

# Ensure the wasmd binary is executable
RUN chmod +x /usr/bin/wasmd

# Copy the .wasmd directory from the build stage
COPY --from=build-env /root/.wasmd /root/.wasmd

# Copy over wasmd depenendencies
RUN mkdir -p /go/pkg/mod/github.com/!cosm!wasm/wasmvm@v1.5.0
COPY --from=build-env /go/pkg/mod/github.com/!cosm!wasm/wasmvm@v1.5.0/ /go/pkg/mod/github.com/!cosm!wasm/wasmvm@v1.5.0/

EXPOSE 36657 36656 9290

# Keep the container running
CMD tail -F /dev/null
