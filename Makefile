lock: package.json
	docker-compose run --rm lock

build:
	docker-compose run --rm build

package:
	docker-compose run --rm package
	git add package.zip

clean:
	docker-compose down --volumes
