DIRS=$(wildcard *.d)
IMAGES=$(patsubst %.d,%,$(DIRS))

build: $(patsubst %,docker-build-%,$(IMAGES))
push: $(patsubst %,docker-push-%,$(IMAGES))

docker-build-%: %.d/Dockerfile
	sudo docker build -t docker.io/vladikr/$*:latest $*.d

docker-push-%:
	sudo docker push docker.io/vladikr/$*:latest

deploy:
	kubectl create $(patsubst %,-f %,$(wildcard */pod.yaml))

undeploy:
	kubectl delete $(patsubst %,-f %,$(wildcard */pod.yaml))

.PHONY: build
