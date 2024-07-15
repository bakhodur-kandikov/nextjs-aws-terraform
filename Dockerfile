FROM alpine:3.19 as base

RUN apk update && apk add --no-cache aws-cli nodejs npm

FROM base as install

WORKDIR /app

COPY package*.json .

RUN npm i

COPY . .

RUN npm run build

FROM base as runner

WORKDIR /app

COPY --from=install /app/.next/standalone server
COPY --from=install /app/.next/static static
COPY --from=install /app/public public

EXPOSE 3000

CMD [ "node", "server/server.js" ]