GOPATH ?=
PATH := $(PATH):$(GOPATH)/bin

ifeq ($(GOPATH),)
  $(error GOPATH is not set)
endif

deps:
	${info ############ GET DEPS #############################}
	GO111MODULE="on" go get sigs.k8s.io/kind@v0.7.0	
	go get sigs.k8s.io/kustomize@v2.0.3

build:
	${info ############ BUILD ################################}
	CGO_ENABLED=0 go build -o ddac-hook ./ 

image: build
	${info ############ BUILD IMAGE ##########################}
	docker build -t k0da/ddac:v1 ./
image-push:
	docker push k0da/ddac:v1

create-cluster: image
	${info ############ CREATE CLUSTER #######################}
	kind create cluster
	kind load docker-image k0da/ddac:v1 

genkeys:
	${info ############ GENEREATE KEYS #######################}
	kubectl create ns ddac
	./hack/gen_keys --service ddac --secret webhook-certs --namespace ddac
patchca:
	${info ############ PATCH CABUNDLE #######################}
	./hack/patch_cabundle

deploy: deps create-cluster genkeys patchca
	${info ############ DEPLOY ###############################}
	kustomize build k8s | kubectl apply -n ddac -f -
	sleep 2
	kubectl wait --for=condition=ready pod -l app=ddac -n ddac --timeout 120s
test: deploy
	${info ############ TEST #################################}
	kubectl create ns test
	kubectl label ns test ddac=true 
	kubectl apply -n test -k github.com/stefanprodan/podinfo//kustomize
	kubectl get po -n test -l mutated=true | grep podinfo
clean:
	kind delete cluster
