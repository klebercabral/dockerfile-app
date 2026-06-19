FROM golang:1.21-alpine AS builder
WORKDIR /app
RUN echo 'package main; import "fmt"; func main() { fmt.Println("Pipeline Segura!") }' > main.go
RUN CGO_ENABLED=0 GOOS=linux go build -o myapp main.go
FROM alpine:3.19
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /home/appuser
COPY --from=builder /app/myapp .
RUN chown -R appuser:appgroup /home/appuser
USER appuser
ENTRYPOINT ["./myapp"]
#TESTE