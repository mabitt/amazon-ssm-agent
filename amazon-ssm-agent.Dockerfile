FROM alpine:3.9
Maintainer MAB <mab+github@mab.net>

ARG PROJECT_URL
ARG DOCKERFILE_VERSION
ARG VERSION
ARG RELEASE

LABEL name="Amazon SSM Agent" \
      description="Amazon EC2 Systems Manager (SSM) agent" \
      help=http://docs.aws.amazon.com/systems-manager/latest/userguide/ssm-agent.html \
      release=${RELEASE} \
      url=${PROJECT_URL} \
      version=${VERSION} \
      dockerfile_version=${DOCKERFILE_VERSION}


USER root

RUN apk add --no-cache ca-certificates && \
  apk update zlib=1.2.11-r0

COPY stage /

VOLUME ["/usr/local/amazon"]
VOLUME ["/etc/amazon/ssm"]

ENTRYPOINT ["/usr/local/amazon/bin/amazon-ssm-agent"]
CMD []
