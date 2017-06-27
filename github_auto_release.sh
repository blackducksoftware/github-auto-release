###############################################################################################################################################################################################
## BlackDuck Github Auto Release 
## v0.0.7
##
## Purpose: Automatically release build artifacts to GitHub on stable, non-SNAPSHOT, project builds. Uses the following project: https://github.com/aktau/github-release. 
##
## How to: to run, ./github_auto_release.sh <parameters>
## Parameters:
##		-b|--buildTool 						required: specify build tool (maven or gradle for now)
##		-f|--artifactFile        			optional: specify file path to project's artifact file (if build artifact is not standard, user can specify to make sure it is released) <CANNOT SPECIFY BOTH A DIRECTORY AND FILE>
##		-t|--artifactType					conditionally optional <if specified, artifactDirectory must also be specified>: if file artifact file type is not .zip, .tar, or .jar, specify a file type here and the script will look for a file in workspace that follows the convention of REPO_NAME-RELEASE_VERSION with specified ending
##												*you may define as .jar to look for file with name repo_name-release_version.jar, or define regex.jar to find a jar file that matches given regex (ex. *.jar matches any jar with any name)
##		-d|--artifactDirectory 				conditionally optional <if specified, artifactType must also be specified>: specify a directory to be zipped and released <CANNOT SPECIFY BOTH A DIRECTORY AND FILE>
##												*note that if there are more multiple directories with subdirectories of the same name, then you must specify assembly/target, or similar
##												*define file paths as follows sub1/sub2/sub3 ...
##		-p|--project						conditionally required: IF using a NuGet project, you must provide a project name
##		-n|--attachArtifacts 				optional: choice to override attaching binaries. If set to false, script will only tag non-SNAPSHOT versions.
##		-m|--releaseDesc         			optional: add description for release to github
##		-o|--organization		   			optional: the name of the organization under which the repo is located (default is blackducksoftware)
##		-ev|--executableVersion   			optional: which version of the GitHub-Release executable to be used (default is v0.7.2 because that is the version this script is being tested with)
##		-ep|--executablePath 	   			optional: where on the user's machine the GitHub-Release executable will live (defualt is set to ~/temp/blackducksoftware)
################################################################################################################################################################################################ 

BUILD_TOOL=""
ARTIFACT_FILE=""
ARTIFACT_DIRECTORY=""
ARTIFACT_TYPE=""
NUGET_PROJECT=""
ATTACH_ARTIFACTS="true"
DESCRIPTION="GitHub Autorelease"
EXECUTABLE_VERSION="v0.7.2" #script built/tested on this
EXECUTABLE_PATH=~/temp/blackducksoftware
ORGANIZATION="blackducksoftware" 

echo " --- Starting GitHub Autorelease Script --- " 

####################################	PARSING INPUT PARAMETERS 		#####################################
args=("$@")
for ((i=0; i<$#; i=i+2));
do
    FLAG=${args[$i]}
    VAL=${args[$i+1]}
    if [[ "$VAL" == -* ]] || [[ "$VAL" == --* ]] || [[ -z "$VAL" ]]; then #should this just be a check for an empty string, or should it be like it is?
    	if [[ "$FLAG" != "-h" ]] && [[ "$FLAG" != "--help" ]]; then
	    	echo " --- ERROR: Incorrectly formatted VAL input. Flag/Value pair < $FLAG, $VAL > causing error. --- "
	    	exit 1
    	fi
    fi

    case $FLAG in
        -b|--buildTool) 
            BUILD_TOOL=$VAL
            ;;
        -d|--artifactDirectory)
			ARTIFACT_DIRECTORY=$VAL
			echo "	- Artifact directory: $ARTIFACT_DIRECTORY. Script will look for this exact directory."
			;;
        -t|--artifactType)
			ARTIFACT_TYPE=$VAL
			echo "	- Artifact type: $ARTIFACT_TYPE. Script will look for this type of file."
			;;
        -f|--artifactFile)
            ARTIFACT_FILE=$VAL
            echo "	- Artifact file path: $ARTIFACT_FILE. Script will look for this exact build artifact."
            ;;
        -p|--nugetProject)
			NUGET_PROJECT=$VAL
			echo " - nuget project: $NUGET_PROJECT."
			;;
        -n|--attachArtifacts)
			ATTACH_ARTIFACTS=$VAL
			echo " - Attach Artifacts: $ATTACH_ARTIFACTS"
			;;
        -m|--releaseDesc) 
            DESCRIPTION=$VAL
            ;;
       	-o|--organization)
			ORGANIZATION=$VAL
			echo "	- Organization: $ORGANIZATION. Owner of repository set."
			;;
        -ev|--executableVersion)
			EXECUTABLE_VERSION=$VAL
			echo "	- Github-release executable version: $EXECUTABLE_VERSION"
			;;
		-ep|--executablePath)
			EXECUTABLE_PATH=$VAL
			echo "	- Github-release excutable location path: $EXECUTABLE_PATH"
			;;
        -h|--help) 
            echo "HELP MENU - options"
			echo "-b|--buildTool 					required: specify build tool (maven, gradle, or nuget)"
			echo "-f|--artifactFile        			optional: specify the exact file path to project's artifact file"
			echo "-d|--artifactDirectory 			conditionally optional <if specified, artifactType must also be specified>: specify a directory to be zipped and released <CANNOT SPECIFY BOTH A DIRECTORY AND FILE>"
			echo "-t|--artifactType 				conditionally optional <if specified, artifactDirectory must also be specified>: specify a file type for script to find, or specify a regex for a file name. (ex. '.jar' will find repo_name-release_version.jar, OR '*repo-name*.jar' will find files matching regex) "
			echo "-n|--attachArtifacts 				optional: choice to override attaching binaries. If set to false, script will only tag non-SNAPSHOT versions."
			echo "-m|--releaseDesc         			optional: add description for release to github (deaflt is 'Github Autorelease')" 
			echo "-o|--organization		   			optional: the name of the organization under which the repo is located (default is blackducksoftware)"
			echo "-ev|--executableVersion   		optional: which version of the GitHub-Release executable to be used (default is v0.7.2)"
			echo "-ep|--executablePath 	   			optional: where on the user's machine the GitHub-Release executable will live (defualt is ~/temp/blackducksoftware)"
			exit 1
			;;
		*)
			echo " --- ERROR: unrecognized FLAG variable in Flag/Value pair: < $FLAG, $VAL > --- "
			exit 1
			;;
    esac
done

if [[ -z "$BUILD_TOOL" ]]; then 
    echo " --- ERROR: BUILD_TOOL ($BUILD_TOOL) (-b|--buildTool) must be specified --- "
    exit 1
elif [[ "$BUILD_TOOL" == "nuget" ]] && [[ -z "$NUGET_PROJECT" ]]; then
	echo " -- ERROR: With nuget project, you MUST specify a project name."
	exit 1
elif ! [[ -z "$ARTIFACT_DIRECTORY" ]] && ! [[ -z "$ARTIFACT_FILE" ]]; then
	echo " --- ERROR: ARTIFACT_DIRECTORY ($ARTIFACT_DIRECTORY) (-d|--artifactDirectory) and ARTIFACT_FILE ($ARTIFACT_FILE) (-f|--artifactFile) cannot both be specified --- "
	exit 1
fi

shopt -s nocasematch
if [[ "$BUILD_TOOL" == "maven" ]]; then 
	RELEASE_VERSION=$(mvn help:evaluate -Dexpression=project.version | grep 'Building')
	RELEASE_VERSION=$(echo $RELEASE_VERSION | awk {'print $NF'})
elif [[ "$BUILD_TOOL" == "gradle" ]]; then
	RELEASE_VERSION=$(./gradlew properties | grep ^version:)
	RELEASE_VERSION=${RELEASE_VERSION##* }
elif [[ "$BUILD_TOOL" == "nuget" ]]; then 
	RELEASE_VERSION=$(find "$NUGET_PROJECT/Properties" -iname "AssemblyInfo.cs")
	RELEASE_VERSION=$(grep "^\[assembly: AssemblyVersion(" $RELEASE_VERSION)
	RELEASE_VERSION=$(echo $RELEASE_VERSION | awk -F "[()]" '{ for (i=2; i<NF; i+=2) print $i }')
	RELEASE_VERSION=${RELEASE_VERSION%?}
	RELEASE_VERSION=$(echo $RELEASE_VERSION | cut -c 2-)
	if [[ $RELEASE_VERSION =~ [0-9]+[.][0-9]+[.][0-9]+[.][0-9]+ ]]; then 
		RELEASE_VERSION=$(echo $RELEASE_VERSION | sed 's/\.[^.]*$//')
	fi 
else 
	echo " --- ERROR: build tool must either be maven, gradle, or nuget. (you entered: $BUILD_TOOL) --- "
	exit 1
fi
shopt -u nocasematch

if [[ "$RELEASE_VERSION" =~ [0-9]+[.][0-9]+[.][0-9]+ ]] && [[ "$RELEASE_VERSION" != *"SNAPSHOT"* ]]; then #regex matches x.y.z where x,y,z are integers

	####################################	FINDING GITHUB-RELEASE EXECUTABLE FILE 		#####################################
	if [ ! -d "$EXECUTABLE_PATH" ]; then
		mkdir -p "$EXECUTABLE_PATH"
		echo "$EXECUTABLE_PATH was just created"
	fi

	EXECUTABLE_PATH_EXISTS=$(find $EXECUTABLE_PATH -name "github-release")
	if [ -z "$EXECUTABLE_PATH_EXISTS" ]; then 
		echo " --- github-release executable does not already exist --- "
		OS_TYPE=$(uname -a | awk {'print $1'}) 
		OS_TYPE=$(echo "$OS_TYPE" | tr '[:upper:]' '[:lower:]') #convert OSTYPE to lower case
		if [[ "$OS_TYPE" == "darwin" ]] || [[ "$OS_TYPE" == "linux" ]]; then
			echo " --- Getting necessary github-release executable from github.com/aktau/github-release --- "
			wget -O $EXECUTABLE_PATH/"$OS_TYPE"-amd64-github-release.tar.bz2 "https://github.com/aktau/github-release/releases/download/$EXECUTABLE_VERSION/$OS_TYPE-amd64-github-release.tar.bz2"
           	tar -xvf "$EXECUTABLE_PATH/$OS_TYPE"-amd64-github-release.tar.bz2 -C $EXECUTABLE_PATH
           	mv $EXECUTABLE_PATH/bin/"$OS_TYPE"/amd64/github-release $EXECUTABLE_PATH
			rm -rf "$EXECUTABLE_PATH/$OS_TYPE"-amd64-github-release.tar.bz2 bin
			echo " --- github-release executable now located in $EXECUTABLE_PATH --- "
		elif [[ "$OS_TYPE" == "mingw" ]]; then #haven't tested on windows
			curl -OL "https://github.com/aktau/github-release/releases/download/v0.7.2/windows-amd64-github-release.zip" 
			unzip windows-amd64-github-release.zip
			mv bin/windows/amd64/github-release $EXECUTABLE_PATH
			rm -R bin windows-amd64-github-release.zip
			echo " --- github-release executable now located in $EXECUTABLE_PATH --- "
		fi
	fi

	####################################	USING INPUT AND EXECUTABLE FILE TO RELEASE/POST TO GITHUB 		#####################################
	REPO_NAME=$(git remote -v)
	REPO_NAME=$(echo $REPO_NAME | awk '{print $2}')
	REPO_NAME=${REPO_NAME##*/}
	REPO_NAME=${REPO_NAME%.*}
	
	echo "Build Tool: $BUILD_TOOL"
	echo "Release Description specified: $DESCRIPTION"
	echo "Repository Name: $REPO_NAME"
	echo "Release Version: $RELEASE_VERSION"

	RELEASE_COMMAND_OUTPUT=$(exec $EXECUTABLE_PATH/github-release release --user $ORGANIZATION --repo $REPO_NAME --tag $RELEASE_VERSION --name $RELEASE_VERSION --description "$DESCRIPTION" 2>&1)
	if [[ -z "$RELEASE_COMMAND_OUTPUT" ]]; then
		echo " --- Release posted to GitHub --- "

		if [[ "$ATTACH_ARTIFACTS" != "true" ]]; then
			echo " --- Override set to NOT attach binaries. Script ending. --- "
			exit 0
		fi

		if ! [[ -z "$ARTIFACT_FILE" ]]; then #locating specific file
			ARTIFACT_FILE=$(find . -iname "$ARTIFACT_FILE")
		elif ! [[ -z "$ARTIFACT_DIRECTORY" ]] && ! [[ -z "$ARTIFACT_TYPE" ]]; then #looking for file pattern in given directory
			FILE_REGEX=$(echo $ARTIFACT_TYPE | sed 's/\.[^.]*$//') #truncates everything after the ".FileExtension"			
			if [[ -z $FILE_REGEX ]]; then 
				ARTIFACT_FILE=$(find "$ARTIFACT_DIRECTORY" -iname "$REPO_NAME-$RELEASE_VERSION$ARTIFACT_TYPE")
			else 
				ARTIFACT_FILE=$(find "$ARTIFACT_DIRECTORY" -iname "$ARTIFACT_TYPE")
			fi 
		else #default case - look for .zip or .tar of repo_name-release_version
			ARTIFACT_FILE=$(find . \( -iname "$REPO_NAME-$RELEASE_VERSION.zip" -o -iname "$REPO_NAME-$RELEASE_VERSION.tar" \) -print -quit)
			if [[ -z "$ARTIFACT_FILE" ]]; then
				echo " --- No artifact files found. No artifact will be attached to release. --- "
				echo " --- Ending GitHub Autorelease Script --- "
				exit 0
			fi		
		fi

		if [[ $(echo $ARTIFACT_FILE | wc -w) -gt 1 ]]; then 
			echo " --- ERROR: More than one file found matching $FILE_REGEX: --- "
			echo "$ARTIFACT_FILE"
			exit 1;
		elif [[ $(echo $ARTIFACT_FILE | wc -w) -eq 0 ]]; then
			echo " --- ERROR: NO files found matching $FILE_REGEX --- "
			exit 1;
		else 	
			ARTIFACT_NAME=$(basename "$ARTIFACT_FILE")
			echo "Artifact File: $ARTIFACT_FILE"
			echo "Artifact Name: $ARTIFACT_NAME"
			POST_COMMAND_OUTPUT=$(exec $EXECUTABLE_PATH/github-release upload --user $ORGANIZATION --repo $REPO_NAME --tag $RELEASE_VERSION --name $ARTIFACT_NAME --file "$ARTIFACT_FILE" 2>&1)	
			
			if [[ -z "$POST_COMMAND_OUTPUT" ]]; then
				echo " --- Artifacts attached to release on GitHub --- "
				echo " --- Ending GitHub Autorelease Script --- "
				exit 0
			else
				echo " --- $POST_COMMAND_OUTPUT --- "
				exit 1
			fi
		fi

	else 
		echo " --- $RELEASE_COMMAND_OUTPUT --- "
		exit 1
	fi 

else
	echo " --- SNAPSHOT found in version name OR version name doesn't follow convention x.y.z where x,y,z are integers separated by .'s - ($RELEASE_VERSION) - NOT releasing to GitHub --- "
	exit 0
fi