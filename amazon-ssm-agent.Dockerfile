FROM scratch

COPY stage /

ENTRYPOINT ["/bin/amazon-ssm-agent"]
CMD []
