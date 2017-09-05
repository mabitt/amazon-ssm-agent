FROM scratch
Maintainer John Torres <enfermo337+github@gmail.com>

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

COPY stage /

USER root

ENTRYPOINT ["/bin/amazon-ssm-agent"]
CMD []
