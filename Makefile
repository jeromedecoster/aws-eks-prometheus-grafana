.SILENT:

help:
	{ grep --extended-regexp '^[a-zA-Z_-]+:.*#[[:space:]].*$$' $(MAKEFILE_LIST) || true; } \
	| awk 'BEGIN { FS = ":.*#[[:space:]]*" } { printf "\033[1;32m%-35s\033[0m%s\n", $$1, $$2 }'

setup: # install eksctl + kubectl, download kube-prometheus
	./make.sh setup

dev: # run the website locally
	./make.sh dev
	
build: # build the production image
	./make.sh build

run: # run the latest built production image on localhost
	./make.sh run

rm: # remove the running container
	./make.sh rm

push: # push production image to docker hub
	./make.sh push

cluster-create: # create the EKS cluster
	./make.sh cluster-create

cluster-deploy-prometheus-grafana: # deploy prometheus + grafana service to EKS
	./make.sh cluster-deploy-prometheus-grafana

cluster-deploy-stress: # deploy stress service to EKS
	./make.sh cluster-deploy-stress

cluster-elb: # get the cluster ELB URL
	./make.sh cluster-elb

cluster-delete: # delete the EKS cluster
	./make.sh cluster-delete
