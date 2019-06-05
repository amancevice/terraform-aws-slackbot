ARG RUNTIME=nodejs10.x

FROM lambci/lambda:build-${RUNTIME}
COPY --from=hashicorp/terraform:0.12.1 /bin/terraform /bin/
COPY package*.json /opt/nodejs/
WORKDIR /opt/nodejs/
RUN npm install --production
WORKDIR /opt/
RUN zip -r /var/task/package.layer.zip nodejs
WORKDIR /var/task
COPY *.tf /var/task/
ARG AWS_DEFAULT_REGION=us-east-1
RUN terraform init
RUN terraform fmt -check
RUN terraform validate
