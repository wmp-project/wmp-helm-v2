helm-install:
	git pull
	helm install $(component) . -f values/$(component).yml
