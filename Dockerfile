ARG RUNTIME=nodejs10.x

FROM lambci/lambda:build-${RUNTIME} AS build
COPY package*.json /opt/nodejs/
WORKDIR /opt/nodejs/
RUN npm install --package-lock-only
RUN npm install --production
WORKDIR /opt/
RUN zip -r /opt/nodejs/package.layer.zip nodejs
WORKDIR /opt/nodejs/

FROM lambci/lambda:build-${RUNTIME} AS test
COPY --from=hashicorp/terraform:0.12.2 /bin/terraform /bin/
COPY --from=build /opt/nodejs/package.layer.zip .
COPY *.tf /var/task/
ARG AWS_DEFAULT_REGION=us-east-1
RUN terraform init
RUN terraform fmt -check
RUN terraform validate
