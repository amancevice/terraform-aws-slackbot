ARG RUNTIME=nodejs12.x
FROM lambci/lambda:build-${RUNTIME}
COPY . .
RUN npm install --production
RUN zip -9r package.zip index.js node_modules package*.json
RUN npm install
