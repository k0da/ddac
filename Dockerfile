FROM alpine:latest

ADD ddac-hook /ddac-hook
ENTRYPOINT ["./ddac-hook"]
