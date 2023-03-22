# build the go binary
FROM golang:1.19.4 as builder
RUN apt-get update && apt-get install -y ca-certificates openssl
ARG cert_location=/usr/local/share/ca-certificates
# Get certificate from "github.com"
RUN openssl s_client -showcerts -connect github.com:443 </dev/null 2>/dev/null|openssl x509 -outform PEM > ${cert_location}/github.crt
# Get certificate from "proxy.golang.org"
RUN openssl s_client -showcerts -connect proxy.golang.org:443 </dev/null 2>/dev/null|openssl x509 -outform PEM >  ${cert_location}/proxy.golang.crt
# Update certificates
RUN update-ca-certificates
# Build app
WORKDIR /build
COPY go.* ./
RUN go mod download
COPY hello.go .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o hello .

# build final alpine image
FROM alpine:3.12.0

# allow user and source root to be passed as args at default to sensibles
ARG APP_USER=app
ARG PROJECT_ROOT=/app/

# install required libs
RUN apk update && apk --no-cache --update add ca-certificates

# create app dir and user
RUN mkdir -p ${PROJECT_ROOT} && \
    addgroup -g 1000 ${APP_USER} && \
    adduser -u 1000 -D ${APP_USER} -G ${APP_USER}

# set local directory
WORKDIR ${PROJECT_ROOT}

# copy final go binary from the builder stage
COPY --from=builder /build/hello ${PROJECT_ROOT}hello

# change permissions on our project directory so that our app user has access
RUN chown -R ${APP_USER}:${APP_USER} ${PROJECT_ROOT}

# labels
LABEL maintainer="Franck De Graeve"
LABEL email="franckdegraeve@gmail.com"
LABEL github="fdegraeve"

# remove binary inside image
RUN rm -Rf /bin/*

# change to our non root user for security purposes
USER ${APP_USER}

# finally expose the port and run the process
EXPOSE 8080
CMD ["./hello"]