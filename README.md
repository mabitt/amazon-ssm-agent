# Amazon SSM Agent

As a fan of [CoreOS Container Linux](https://coreos.com/os/docs/latest) it is my go-to platform of choice.
Coupled with the fact that I often work with AWS services & deployments, I look for ways to satisfy AWS goals with
CoreOS solutions.


I came across an article from [Levent Yalcin (a.k.a. LevOps)](https://medium.com/levops/how-to-work-with-aws-simple-system-manager-on-coreos-4741853dfd50) which inspired me to adopt SSM with a slight twist.
Trying to live the values of Container Linux, I have introduced this as a container and merged it with my example of [aws-coreos-ecs-userdata](https://github.com/tf-modules/aws-coreos-ecs-userdata).

The result is an Amazon ECS cluster that support SSM.

## Building this image

The quickest way to build this package is simply `make all/amazon-ssm-agent`
This will
 - determine the latest release
 - download the bundle
 - compile the binary
 - package the image and it's configuration
 - push to the image repo
 - generate a generic systemd drop-in

### Building & Pushing to a customer repo

```bash
$ make all/amazon-ssm-agent DOCKER_REGISTRY=quay.io DOCKER_IMAGE_REPO=my_account
```

### Running the agent

- Using with [ignition](https://coreos.com/ignition/docs/latest/)

Create a snippet similar to:

```yaml
  - name: amazon-ssm-agent.service
    enable: true
    contents: |
      [Unit]
      Description=Amazon SSM Agent
      After=docker.service
      Requires=docker.service

      [Service]
      Restart=on-failure
      RestartSec=30
      RestartPreventExitStatus=5
      SyslogIdentifier=ssm-agent
      ExecStartPre=-/usr/bin/docker kill amazon-ssm-agent
      ExecStartPre=-/usr/bin/docker rm amazon-ssm-agent
      ExecStartPre=/usr/bin/docker pull quay.io/johnt337/amazon-ssm-agent
      ExecStart=/usr/bin/docker run -d --name amazon-ssm-agent quay.io/johnt337/amazon-ssm-agent
      ExecStop=/usr/bin/docker stop amazon-ssm-agent

      [Install]
      WantedBy=multi-user.target
```
   * Don't forget to run it through [config-transpiler](https://github.com/coreos/container-linux-config-transpiler)

- Using with other linux distribution 

Generate the systemd template:

```bash
$ make gen-systemd-unit
```

This will create a file called `amazon-ssm-agent.service`
Review (and optionally edit) then upload to your server and run `systemctl enable amazon-ssm-agent.service`
