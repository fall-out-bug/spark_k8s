# Spark Custom Images Makefile

REGISTRY ?= localhost:5000
IMAGE_NAME ?= spark-custom

.PHONY: all build-3.5.7 build-3.5.8 build-4.1.0 build-4.1.1 push-3.5.7 push-3.5.8 push-4.1.0 push-4.1.1 clean

all: build-3.5.7 build-3.5.8 build-4.1.0 build-4.1.1

build-3.5.7:
	@echo "Building spark-custom:3.5.7..."
	docker build -t $(REGISTRY)/$(IMAGE_NAME):3.5.7 -f Dockerfile.3.5.7 .
	docker tag $(REGISTRY)/$(IMAGE_NAME):3.5.7 $(REGISTRY)/$(IMAGE_NAME):3.5

build-3.5.8:
	@echo "Building spark-custom:3.5.8..."
	docker build -t $(REGISTRY)/$(IMAGE_NAME):3.5.8 -f Dockerfile.3.5.8 .
	docker tag $(REGISTRY)/$(IMAGE_NAME):3.5.8 $(REGISTRY)/$(IMAGE_NAME):3.5

build-4.1.0:
	@echo "Building spark-custom:4.1.0..."
	docker build -t $(REGISTRY)/$(IMAGE_NAME):4.1.0 -f Dockerfile.4.1.0 .
	docker tag $(REGISTRY)/$(IMAGE_NAME):4.1.0 $(REGISTRY)/$(IMAGE_NAME):4.1

build-4.1.1:
	@echo "Building spark-custom:4.1.1..."
	docker build -t $(REGISTRY)/$(IMAGE_NAME):4.1.1 -f Dockerfile.4.1.1 .
	docker tag $(REGISTRY)/$(IMAGE_NAME):4.1.1 $(REGISTRY)/$(IMAGE_NAME):4.1

push-3.5.7: build-3.5.7
	@echo "Pushing spark-custom:3.5.7..."
	docker push $(REGISTRY)/$(IMAGE_NAME):3.5.7
	docker push $(REGISTRY)/$(IMAGE_NAME):3.5

push-3.5.8: build-3.5.8
	@echo "Pushing spark-custom:3.5.8..."
	docker push $(REGISTRY)/$(IMAGE_NAME):3.5.8
	docker push $(REGISTRY)/$(IMAGE_NAME):3.5

push-4.1.0: build-4.1.0
	@echo "Pushing spark-custom:4.1.0..."
	docker push $(REGISTRY)/$(IMAGE_NAME):4.1.0
	docker push $(REGISTRY)/$(IMAGE_NAME):4.1

push-4.1.1: build-4.1.1
	@echo "Pushing spark-custom:4.1.1..."
	docker push $(REGISTRY)/$(IMAGE_NAME):4.1.1
	docker push $(REGISTRY)/$(IMAGE_NAME):4.1

push: push-3.5.7 push-3.5.8 push-4.1.0 push-4.1.1

clean:
	@echo "Cleaning build cache..."
	docker system prune -f

help:
	@echo "Spark Custom Images Build"
	@echo ""
	@echo "Usage:"
	@echo "  make build-3.5.7    Build Spark 3.5.7 image"
	@echo "  make build-3.5.8    Build Spark 3.5.8 image"
	@echo "  make build-4.1.0    Build Spark 4.1.0 image"
	@echo "  make build-4.1.1    Build Spark 4.1.1 image"
	@echo "  make push-3.5.7     Build and push Spark 3.5.7 image"
	@echo "  make push-3.5.8     Build and push Spark 3.5.8 image"
	@echo "  make push-4.1.0     Build and push Spark 4.1.0 image"
	@echo "  make push-4.1.1     Build and push Spark 4.1.1 image"
	@echo "  make push           Build and push all images"
	@echo "  make clean          Clean Docker build cache"
	@echo ""
	@echo "Variables:"
	@echo "  REGISTRY    Docker registry (default: localhost:5000)"
	@echo "  IMAGE_NAME  Image name (default: spark-custom)"
	@echo ""
	@echo "Examples:"
	@echo "  make build-3.5.8 REGISTRY=registry.example.com IMAGE_NAME=spark-k8s"
	@echo "  make all              Build all 4 images (3.5.7, 3.5.8, 4.1.0, 4.1.1)"
	@echo "  make push-3.5.8       Build and push 3.5.8"
