ARG RUNTIME=nodejs10.x

FROM lambci/lambda:build-${RUNTIME} AS install
COPY --from=hashicorp/terraform:0.11.14 /bin/terraform /bin/
COPY package.json /opt/nodejs/
WORKDIR /opt/nodejs/
RUN npm install --production
WORKDIR /var/task/
COPY *.tf /var/task/
RUN terraform init

FROM install AS build
WORKDIR /opt/
RUN zip -r /var/task/package.layer.zip .
WORKDIR /var/task/
COPY index.js .
ARG AWS_DEFAULT_REGION=us-east-1
ARG TF_VAR_kms_key_id=12345678-abcd-1234-abcd-1234567890ab
ARG TF_VAR_secret_name=secret_name
RUN terraform fmt -check
RUN terraform validate

FROM lambci/lambda:${RUNTIME}
COPY --from=build /opt/ /opt/
COPY --from=build /var/task/index.js /var/task/
