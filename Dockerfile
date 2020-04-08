ARG RUNTIME=nodejs12.x
ARG TERRAFORM=latest

FROM lambci/lambda:build-${RUNTIME} AS zip
COPY . .
RUN npm install --production
RUN zip -9r package.zip index.js node_modules package*.json
RUN npm install

FROM lambci/lambda:${RUNTIME} AS dev
COPY --from=zip /var/task .

FROM hashicorp/terraform:${TERRAFORM} AS test
COPY --from=zip /var/task .
ARG AWS_DEFAULT_REGION=us-east-1
RUN terraform init
RUN terraform fmt -check
RUN terraform validate
