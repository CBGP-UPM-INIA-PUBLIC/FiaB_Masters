#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
CWD=$PWD
export DOCKER_BUILDKIT=0
export COMPOSE_DOCKER_CLI_BUILD=0

function ctrl_c() {
        docker-compose -f "$CWD/metadata/docker-compose-${P}.yml" down
        docker-compose -f "$CWD/bootstrap/docker-compose-${P}.yml" down
        docker-compose rm -f "$CWD/metadata/docker-compose-${P}.yml" -s
        docker-compose rm -f "$CWD/bootstrap/docker-compose-${P}.yml" -s
        docker network rm bootstrap_default bootstrap_graphdb_net
        docker rmi -f bootstrap_graph_db_repo_manager:latest

        if [ $production = "false" ]; then
          echo ""
          echo -e "${GREEN}because this is NOT a production server, I will now delete all assets and volumes.  You must re-run this installation script as a production server to recover.$NC"
          echo ""
          rm -rf "$CWD/test-ready-to-go"
          docker volume remove -f $P-graphdb $P-fdp-client-assets $P-fdp-client-css $P-fdp-client-scss $P-fdp-server $P-mongo-data $P-mongo-init
        fi
        rm "${CWD}/metadata/docker-compose-${P}.yml"
        rm "${CWD}/bootstrap/docker-compose-${P}.yml"
        rm "${CWD}/metadata/fdp/application-${P}.yml"

        exit 2
}

trap ctrl_c 2





  uri="http://localhost:7070"
  P="masters"
  FDP_PORT="7070"
  GDB_PORT="7200"

mkdir $HOME/tmp
export TMPDIR=$HOME/tmp
# needed by the main.py script
export FDP_PREFIX=$P

docker network rm bootstrap_default
docker rm -f  bootstrap_graphdb_1 metadata_fdp_1 metadata_fdp_client_1
docker volume remove -f "${P}-graphdb ${P}-fdp-client-assets ${P}-fdp-client-css ${P}-fdp-client-scss ${P}-fdp-server ${P}-mongo-data ${P}-mongo-init"

docker volume create "${P}-graphdb"
docker volume create "${P}-fdp-server"
docker volume create "${P}-fdp-client-assets"
docker volume create "${P}-fdp-client-scss"
docker volume create "${P}-mongo-data"
docker volume create "${P}-mongo-init"


echo ""
echo ""
echo -e "${GREEN}Creating GraphDB and bootstrapping it - this will take about 10 minutes"
echo -e "Go make a nice cup of tea and then come back to check on progress"
echo -e "${NC}"
echo ""

cd bootstrap
cp docker-compose-template.yml "docker-compose-${P}.yml"
sed -i s/{PREFIX}/${P}/ "docker-compose-${P}.yml"

docker-compose -f "docker-compose-${P}.yml" up --build -d
sleep 13
echo ""
echo -e "${GREEN}Setting up FAIR Data Point client and server${NC}"
echo ""




cd ../metadata

cp docker-compose-template.yml "docker-compose-${P}.yml"
cp ./fdp/application-template.yml "./fdp/application-${P}.yml"
sed -i s/{PREFIX}/$P/ "docker-compose-${P}.yml"
sed -i s/{FDP_PORT}/$FDP_PORT/ "docker-compose-${P}.yml"
sed -i s/{PREFIX}/$P/ "./fdp/application-${P}.yml"
sed -i s/{FDP_PORT}/$FDP_PORT/ "./fdp/application-${P}.yml"
sed -i s%{GUID}%$uri% "./fdp/application-${P}.yml"


docker-compose -f "docker-compose-${P}.yml" up --build -d


sleep 15

echo ""
echo -e "${GREEN}Creating a production server folder in ${NC} ./${P}-ready-to-go/"
echo ""

cd ..
cp -r ./FAIR-ready-to-go ./${P}-ready-to-go
cp ./${P}-ready-to-go/docker-compose-template.yml "./${P}-ready-to-go/docker-compose-${P}.yml"
rm ./${P}-ready-to-go/docker-compose-template.yml
cp ./${P}-ready-to-go/fdp/application-template.yml "./${P}-ready-to-go/fdp/application-${P}.yml"
rm ./${P}-ready-to-go/fdp/application-template.yml
cp ./${P}-ready-to-go/.env_template "./${P}-ready-to-go/.env"
sed -i s/{PREFIX}/${P}/ "./${P}-ready-to-go/docker-compose-${P}.yml"
sed -i s/{FDP_PORT}/${FDP_PORT}/ "./${P}-ready-to-go/docker-compose-${P}.yml"
sed -i s/{GDB_PORT}/${GDB_PORT}/ "./${P}-ready-to-go/docker-compose-${P}.yml"
sed -i s/{PREFIX}/${P}/ "./${P}-ready-to-go/fdp/application-${P}.yml"
sed -i s/{FDP_PORT}/${FDP_PORT}/ "./${P}-ready-to-go/fdp/application-${P}.yml"
sed -i s%{GUID}%${uri}% "./${P}-ready-to-go/fdp/application-${P}.yml"
sed -i s/{CDE_DB_NAME}/${P}-cde/ "./${P}-ready-to-go/.env"
sed -i s%{GUID}%$uri% "./${P}-ready-to-go/.env"

echo ""
echo ""
echo -e "${GREEN}Installation Complete!"

docker network rm bootstrap_default bootstrap_graphdb_net
docker rmi -f bootstrap_graph_db_repo_manager:latest

rm "${CWD}/metadata/docker-compose-${P}.yml"
rm "${CWD}/bootstrap/docker-compose-${P}.yml"
rm "${CWD}/metadata/fdp/application-${P}.yml"
mv "${CWD}/${P}-ready-to-go/docker-compose-${P}.yml" "${CWD}/${P}-ready-to-go/docker-compose.yml"
mv "${CWD}/${P}-ready-to-go/" ~/

