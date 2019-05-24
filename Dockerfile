ARG RUNTIME=nodejs10.x

FROM lambci/lambda:build-${RUNTIME} AS install
COPY --from=hashicorp/terraform:0.12.0 /bin/terraform /bin/
COPY . .
RUN npm install --production
RUN terraform init

FROM install AS build
COPY --from=install /var/task/node_modules/ /opt/nodejs/node_modules/
ARG AWS_DEFAULT_REGION=us-east-1
RUN cd /opt/ && zip -r /var/task/package.layer.zip *
RUN terraform fmt -check
RUN terraform validate
RUN zip package.zip *.tf index.js package.layer.zip
