FROM softonic/node-prune AS prune

FROM polinux/stress AS stress

FROM node:14.11-alpine AS build
# With `NODE_ENV=production` npm install will skip devDependencies packages
ENV NODE_ENV production
WORKDIR /app
COPY --from=prune /go/bin/node-prune /usr/local/bin/
ADD . .
RUN npm install --quiet
RUN node-prune

FROM node:14.11-alpine
ENV NODE_ENV production
WORKDIR /app
COPY --from=build /app .
COPY --from=stress /usr/local/bin/stress /usr/bin
CMD ["node", "server.js"]