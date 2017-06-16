#########################################
## BlackDuck Github Auto Release 
## v0.0.1
##
## Purpose:
##
## How to: 
#########################################

BLUE='\033[0;34m'
NC='\033[0m'
YELLOW='\033[0;33m'
RED='\033[0;31m' 
GREEN='\033[0;32m' 

BUILD_TOOL=""
GITHUB_TOKEN=""
FILEPATH=""
DESCRIPTION=""

while getopts "b:o:f:d:h" OPTION
do
    case $OPTION in
        b)
                BUILD_TOOL=$OPTARG
                ;;
        o)
                export GITHUB_TOKEN=$OPTARG
                ;;
        f)
                FILEPATH=$OPTARG
                ;;
        d)
                DESCRIPTION=$OPTARG
                ;;
        h)
                echo "HELP MENU - options"
                echo "--buildTool           required: specify build tool"
                echo "--gitToken            required: specify personal github authentication token"
                echo "--artifactPath        optional: specify file path to project's artifact file"
                echo "--releaseDesc         optional: add description for release to github" #maybe make this -m to match github?
                exit 1
                ;;
        esac
done

if [ "$BUILD_TOOL" == "" ] || [ "$GITHUB_TOKEN" == "" ]; then 
    echo -e " --- ${RED}ERROR: BUILD_TOOL (-b) and GITHUB_TOKEN must be specified (-o)${NC} --- "
    exit 1
fi

if [[ "$DESC" == "" ]]; then
	DESC="GitHub Autorelease" 
fi

	EXECUTABLE_PATH=$(find ~/temp/blackducksoftware -name "github-release")
	if [[ "$EXECUTABLE_PATH" == "" ]]; then
			echo -e " --- ${BLUE}Getting necessary github-release executable from github.com/aktau/github-release${NC} --- "
			OS_TYPE=$(uname -a | awk {'print $1'})

			if [[ "$OS_TYPE" == "Linux" ]]; then
				mkdir ~/temp/blackducksoftware
				wget -O ~/temp/blackducksoftware/linux-amd64-github-release.tar.bz2 "https://github.com/aktau/github-release/releases/download/v0.7.2/linux-amd64-github-release.tar.bz2" 
				bzip2 -d ~/temp/blackducksoftware/linux-amd64-github-release.tar.bz2
				tar -xvf ~/temp/blackducksoftware/linux-amd64-github-release.tar -C ~/temp/blackducksoftware/
				mv ~/temp/blackducksoftware/bin/linux/amd64/github-release ~/temp/blackducksoftware/github-release
				rm -R ~/temp/blackducksoftware/bin ~/temp/blackducksoftware/linux-amd64-github-release.tar
			elif [[ "$OS_TYPE" == "Darwin" ]]; then
				mkdir ~/temp/blackducksoftware
				wget -O ~/temp/blackducksoftware/darwin-amd64-github-release.tar.bz2 "https://github.com/aktau/github-release/releases/download/v0.7.2/darwin-amd64-github-release.tar.bz2" 
				bzip2 -d ~/temp/blackducksoftware/darwin-amd64-github-release.tar.bz2
				tar -xvf ~/temp/blackducksoftware/darwin-amd64-github-release.tar -C ~/temp/blackducksoftware/
				mv ~/temp/blackducksoftware/bin/darwin/amd64/github-release ~/temp/blackducksoftware/github-release
				rm -R ~/temp/blackducksoftware/bin ~/temp/blackducksoftware/darwin-amd64-github-release.tar
			elif [[ "$OS_TYPE" == "Windows" ]]; then
				wget -O ~/temp/blackducksoftware/windows-amd64-github-release.zip "https://github.com/aktau/github-release/releases/download/v0.7.2/windows-amd64-github-release.zip" 
				unzip ~/temp/blackducksoftware/windows-amd64-github-release.zip -d ~/temp/blackducksoftware/
				mv ~/temp/blackducksoftware/bin/windows/amd64/github-release.exe ~/temp/blackducksoftware/
				rm -R ~/temp/blackducksoftware/bin ~/temp/blackducksoftware/windows-amd64-github-release.zip
			elif [[ "$OS_TYPE" == "Freebsd" ]]; then
				mkdir ~/temp/blackducksoftware
				wget -O ~/temp/blackducksoftware/freebds-amd64-github-release.tar.bz2 "https://github.com/aktau/github-release/releases/download/v0.7.2/freebds-amd64-github-release.tar.bz2" 
				bzip2 -d ~/temp/blackducksoftware/freebds-amd64-github-release.tar.bz2
				tar -xvf ~/temp/blackducksoftware/freebds-amd64-github-release.tar -C ~/temp/blackducksoftware/
				mv ~/temp/blackducksoftware/bin/freebds/amd64/github-release ~/temp/blackducksoftware/github-release
				rm -R ~/temp/blackducksoftware/bin ~/temp/blackducksoftware/freebds-amd64-github-release.tar
			else
				echo -e " --- ${RED}OS type unrecognizable. Exiting shell.${NC} --- "
				exit 1
			fi

			echo " --- github-release executable now located in ~/temp/blackducksoftware --- "
	fi

	if [[ "$BUILD_TOOL" == "maven" ]]; then 
		RELEASE_VERSION=$(mvn help:evaluate -Dexpression=project.version | grep -e 'Building')
		RELEASE_VERSION=$(echo $RELEASE_VERSION | awk {'print $NF'})
	elif [[ "$BUILD_TOOL" == "gradle" ]]; then
		RELEASE_VERSION=$(./gradlew properties | grep ^version:)
		RELEASE_VERSION=${RELEASE_VERSION##* }
	fi

	if [[ $RELEASE_VERSION != *"SNAPSHOT"* ]]; then
		REPO_NAME=$(git remote -v)
		REPO_NAME=$(echo $REPO_NAME | awk '{print $2}')
		REPO_NAME=${REPO_NAME##*/}
		REPO_NAME=${REPO_NAME%.*}

		if [[ "$FILEPATH" == "" ]]; then 
			FILEPATH=$(find . -iname "$REPO_NAME-$RELEASE_VERSION.zip") #should this also look for .tar files?
		fi
		ARTIFACT_NAME=$(basename "$FILEPATH")
		
		echo -e "${BLUE}Build Tool:${NC} $BUILD_TOOL"
		echo -e "${BLUE}Release Description specified:${NC} $DESC"
		echo -e "${BLUE}Repository Name:${NC} $REPO_NAME"
		echo -e "${BLUE}Release Version:${NC} $RELEASE_VERSION"

		RELEASE_COMMAND_OUTPUT=$(exec ~/temp/blackducksoftware/github-release release --user patrickwilliamconway --repo $REPO_NAME --tag $RELEASE_VERSION --name $RELEASE_VERSION --description "$DESC" 2>&1)
		#RELEASE_COMMAND_OUTPUT=""
		if [[ "$RELEASE_COMMAND_OUTPUT" == "" ]]; then
			echo -e " --- ${GREEN}Release posted to GitHub${NC} --- "
			
			if [[ "$FILEPATH" != "" ]]; then 
				echo -e "${BLUE}Artifact Filepath:${NC} $FILEPATH"
				echo -e "${BLUE}Artifact Name:${NC} $ARTIFACT_NAME"
				
				POST_COMMAND_OUTPUT=$(exec ~/temp/blackducksoftware/github-release upload --user patrickwilliamconway --repo $REPO_NAME --tag $RELEASE_VERSION --name $ARTIFACT_NAME --file "$FILEPATH" 2>&1)
				#POST_COMMAND_OUTPUT=""
				if [[ "$POST_COMMAND_OUTPUT" == "" ]]; then
					echo -e " --- ${GREEN}Artifacts attached to release on GitHub${NC} --- "
				else
					echo -e "--- ${RED}$POST_COMMAND_OUTPUT${NC} --- "
					exit 1
				fi
			else
				echo -e " --- ${YELLOW}No artifact files found. No artifact will be attached to release.${NC} --- "
			fi
		else 
			echo -e " --- ${RED}$RELEASE_COMMAND_OUTPUT${NC} --- "
			exit 1
		fi 
	else
		echo -e " --- SNAPSHOT found in version name (${YELLOW}$RELEASE_VERSION${NC}) - NOT releasing to GitHub --- "
	fi

