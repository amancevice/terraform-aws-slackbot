ARG RUNTIME=nodejs10.x
ARG TERRAFORM=latest

FROM lambci/lambda:build-${RUNTIME} AS build
COPY index.js package*.json /var/task/
RUN npm install --production
RUN zip -r package.zip index.js node_modules package*.json
RUN npm install

FROM hashicorp/terraform:${TERRAFORM} AS test
COPY --from=build /var/task/package.zip .
COPY *.tf /var/task/
ARG AWS_DEFAULT_REGION=us-east-1
RUN terraform init
RUN terraform fmt -check
RUN terraform validate
