package main

import (
	"flag"
	"crypto/tls"
	"github.com/golang/glog"
	"net/http"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"context"
)

func main() {
	var parameters SrvParams

	// get command line parameters
	flag.IntVar(&parameters.port, "port", 443, "Webhook server port.")
	flag.StringVar(&parameters.certFile, "tlsCertFile", "/etc/webhook/certs/cert.pem", "File containing the x509 Certificate for HTTPS.")
	flag.StringVar(&parameters.keyFile, "tlsKeyFile", "/etc/webhook/certs/key.pem", "File containing the x509 private key to --tlsCertFile.")
	flag.Parse()

	pair, err := tls.LoadX509KeyPair(parameters.certFile, parameters.keyFile)
	if err != nil {
		glog.Errorf("Failed to load key pair: %v", err)
	}

	srv := &WebhookServer{
		server: &http.Server{
			Addr:      fmt.Sprintf(":%v", parameters.port),
			TLSConfig: &tls.Config{Certificates: []tls.Certificate{pair}},
		},
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/mutate", srv.serve)
	srv.server.Handler = mux

	go func() {
		if err := srv.server.ListenAndServeTLS("", ""); err != nil {
			glog.Errorf("Failed to listen and serve webhook server: %v", err)
		}
	}()
	glog.Info("Server started")

	signalChan := make(chan os.Signal, 1)
	signal.Notify(signalChan, syscall.SIGINT, syscall.SIGTERM)
	<-signalChan

	glog.Infof("Got SIGTERM, shutting down...")
	srv.server.Shutdown(context.Background())
}
