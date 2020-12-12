ARG NODE_VERSION=12
FROM amazon/aws-lambda-nodejs:${NODE_VERSION}
RUN yum install -y zip
COPY . .
RUN npm install --production
RUN zip -9r package.zip index.js node_modules package*.json
RUN npm install
VOLUME /root
VOLUME /var/task
CMD [ "index.handler" ]
