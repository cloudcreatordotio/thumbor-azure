FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Add deadsnakes PPA for Python 3.11
RUN apt-get update && apt-get install -y \
    software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update

# Test installing each group of packages
RUN apt-get install -y python3.11 python3.11-dev python3.11-distutils python3.11-venv python3-pip build-essential

# Try installing the nginx cache purge module separately
RUN apt-get install -y nginx libnginx-mod-http-cache-purge