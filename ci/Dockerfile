# ci/Dockerfile — builder image (text-only stub).
# Base is digest-pinned for reproducibility.
# TODO: fill real digest before builder use.
FROM debian:stable-slim
RUN apt-get update && apt-get install -y --no-install-recommends git python3
COPY . /src
WORKDIR /src
CMD ["sh", "ci/jobs-mr.sh"]
