FROM golang:1.26-alpine3.24 AS builder

WORKDIR /app

RUN apk update && apk upgrade --no-cache

RUN echo 'package main; import "fmt"; func main() { fmt.Println("Pipeline Segura!") }' > main.go

RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o myapp main.go

FROM alpine:3.24

RUN apk update && apk upgrade --no-cache && rm -rf /var/cache/apk/*

RUN addgroup -S appgroup && \
    adduser -S -D -H -s /sbin/nologin -G appgroup appuser

WORKDIR /app

COPY --from=builder --chown=appuser:appgroup /app/myapp .

RUN chmod 550 /app/myapp

USER appuser

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["test", "-x", "/app/myapp"]

STOPSIGNAL SIGTERM

ENTRYPOINT ["./myapp"]