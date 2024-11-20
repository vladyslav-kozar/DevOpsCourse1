 #!/bin/bash

docker pull vladyslavkozar/devopscourse-vlad:latest

docker run -d --name devopscourse-vlad -p 80:80 vladyslavkozar/devopscourse-vlad
