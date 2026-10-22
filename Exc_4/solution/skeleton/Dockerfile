FROM golang:1.27 AS builder

WORKDIR /app
COPY . /app

RUN sed -i 's/\r$//' /app/scripts/build-application.sh \
    && chmod +x /app/scripts/build-application.sh \
    && /app/scripts/build-application.sh

FROM alpine AS run

WORKDIR /app
COPY --from=builder /app/ordersystem /app/ordersystem

USER nobody

EXPOSE 3000
ENTRYPOINT ["/app/ordersystem"]