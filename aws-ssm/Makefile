def:
	git pull
	terraform init
	terraform apply -auto-approve

docker-build:
	git pull
	aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 349558942960.dkr.ecr.us-east-1.amazonaws.com
	docker build -t 349558942960.dkr.ecr.us-east-1.amazonaws.com/ssm-pull .
	docker push 349558942960.dkr.ecr.us-east-1.amazonaws.com/ssm-pull

