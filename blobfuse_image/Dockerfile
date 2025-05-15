FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y wget curl gnupg2 software-properties-common fuse ca-certificates && \
    apt-get clean

RUN wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -y blobfuse2 && \
    rm packages-microsoft-prod.deb

ENTRYPOINT ["/bin/sh"]
