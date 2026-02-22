FROM golang:1.22-alpine AS builder

WORKDIR /app

COPY go.mod ./
RUN go mod download

COPY . .
RUN go build -o notification-service .

FROM alpine:3.20

WORKDIR /app
COPY --from=builder /app/notification-service ./notification-service

EXPOSE 8080

CMD ["./notification-service"]
