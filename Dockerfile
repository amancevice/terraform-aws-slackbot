ARG RUNTIME=nodejs12.x
ARG TERRAFORM=latest

FROM lambci/lambda:build-${RUNTIME} AS build
COPY . .
RUN npm install --production
RUN zip -9r package.zip index.js node_modules package*.json

FROM lambci/lambda:${RUNTIME} AS dev
COPY --from=build /var/task .

FROM hashicorp/terraform:${TERRAFORM} AS test
COPY --from=build /var/task .
ARG AWS_DEFAULT_REGION=us-east-1
RUN terraform init
RUN terraform fmt -check
RUN terraform validate
