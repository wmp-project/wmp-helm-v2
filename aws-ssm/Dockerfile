FROM        docker.io/redhat/ubi9
ENTRYPOINT  ["bash", "/run.sh"]
COPY        run.sh /
RUN         dnf install unzip jq -y && curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip && ./aws/install && rm -rf awscliv2.zip ./aws && dnf remove unzip -y && dnf clean all


