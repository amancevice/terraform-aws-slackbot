ARG RUNTIME=nodejs10.x

FROM lambci/lambda:build-${RUNTIME} AS build
COPY index.js package*.json /var/task/
RUN npm install --package-lock-only
RUN npm install --production
RUN zip -r package.zip index.js node_modules package*.json

FROM lambci/lambda:build-${RUNTIME} AS test
COPY --from=hashicorp/terraform:0.12.2 /bin/terraform /bin/
COPY --from=build /var/task/package.zip .
COPY *.tf /var/task/
ARG AWS_DEFAULT_REGION=us-east-1
RUN terraform init
RUN terraform fmt -check
RUN terraform validate
