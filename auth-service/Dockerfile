FROM golang:tip-trixie AS builder

WORKDIR /app

COPY . .

RUN go mod tidy && CGO_ENABLED=0 GOOS=linux go build .

FROM alpine:3.23.2

RUN apk update && apk upgrade --no-cache

COPY --from=builder /app/auth-service /usr/local/bin/auth-service

CMD ["auth-service"]