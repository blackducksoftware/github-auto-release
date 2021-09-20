#####################################################################################################
## BlackDuck Github Auto Release
## v2.0.0
##
## Purpose: Automatically release build artifacts to GitHub on stable, non-SNAPSHOT, project builds.
##    Uses the following project: https://github.com/aktau/github-release.
##
## How to: to run, ./github_auto_release.sh <parameters>
#####################################################################################################
function __log_and_exit() {
  __log "${1}"
  exit "$2"
}

function __log() {
  echo "${1}"
}

_usage_="
Parameters:
  -d|--artifactDirectory    conditionally optional <if specified, artifactType must also be specified>: specify a directory to be zipped and released
                              <CANNOT SPECIFY BOTH -d|--artifactDirectory AND -f|--artifactFile>
                              *note that if there are more multiple directories with subdirectories of the same name, then you must specify assembly/target, or similar
                              *define file paths as follows sub1/sub2/sub3 ...
  -t|--artifactType         conditionally optional <if specified, artifactDirectory must also be specified>: if file artifact file type is not .zip, .tar, or .jar,
                              specify a file type here and the script will look for a file in workspace that follows the convention of REPO_NAME-RELEASE_VERSION
                              with specified ending
                              *you may define as .jar to look for file with name repo_name-release_version.jar, or define regex.jar to find a jar file that matche
                              given regex (ex. *.jar matches any jar with any name)
  -f|--artifactFile         optional: specify file path to project's artifact file (if build artifact is not standard, user can specify to make sure it is released)
                              <CANNOT SPECIFY BOTH -d|--artifactDirectory AND -f|--artifactFile>
  -n|--attachArtifacts      optional: choice to override attaching binaries. If set to false, script will only tag non-SNAPSHOT versions.
  -b|--buildTool            conditionally required: specify build tool (maven or gradle for now) if you are not providing a releaseVersion.
  -m|--releaseDesc          optional: add description for release to github
  -ep|--executablePath      optional: where on the user's machine the GitHub-Release executable will live (default is set to ~/temp/GARTool)
  -ev|--executableVersion   optional: which version of the GitHub-Release executable to be used (default is v0.10.0)
  -p|--nugetProject         conditionally required: IF using a NuGet project, you must provide a project name
  -o|--owner                required: the name of the owner under which the repo is located
  -v|--releaseVersion       conditionally required: specify the release version of the project.
  -br|--branch              optional: the branch that should be tagged on release
  -h|--help                 help menu
"

ARTIFACT_DIRECTORY=""
ARTIFACT_FILE=""
ARTIFACT_TYPE=""
ATTACH_ARTIFACTS="true"
BUILD_TOOL=""
DESCRIPTION="GitHub Autorelease"
EXECUTABLE_PATH=~/temp/GARTool
EXECUTABLE_VERSION="v0.10.0"
NUGET_PROJECT=""
OWNER=""
RELEASE_VERSION=""
TARGET=""

__log " --- Starting GitHub Autorelease Script --- "

####################################	PARSING INPUT PARAMETERS 		#####################################
args=("$@")
for ((i=0; i<$#; i=i+2)); do
    FLAG=${args[$i]}
    VAL=${args[$i+1]}
    if [[ "$VAL" == -* ]] || [[ "$VAL" == --* ]] || [[ -z "$VAL" ]]; then #should this just be a check for an empty string, or should it be like it is?
    	if [[ "$FLAG" != "-h" ]] && [[ "$FLAG" != "--help" ]]; then
        __log_and_exit " --- ERROR: Incorrectly formatted VAL input. Flag/Value pair < $FLAG, $VAL > causing error. --- " 1
    	fi
    fi

    case $FLAG in
      -d|--artifactDirectory)
        ARTIFACT_DIRECTORY=$VAL
        __log "	- Artifact directory: $ARTIFACT_DIRECTORY. Script will look for this exact directory."
        ;;
      -t|--artifactType)
        ARTIFACT_TYPE=$VAL
        __log "	- Artifact type: $ARTIFACT_TYPE. Script will look for this type of file."
        ;;
      -f|--artifactFile)
        ARTIFACT_FILE=$VAL
        __log "	- Artifact file path: $ARTIFACT_FILE. Script will look for this exact build artifact."
        ;;
      -b|--buildTool)
        BUILD_TOOL=$VAL
        ;;
      -v|--releaseVersion)
        RELEASE_VERSION=$VAL
        ;;
      -o|--owner)
        OWNER=$VAL
        ;;
      -p|--nugetProject)
        NUGET_PROJECT=$VAL
        __log "	- nuget project: $NUGET_PROJECT."
        ;;
      -n|--attachArtifacts)
        ATTACH_ARTIFACTS=$VAL
        __log "	- Attach Artifacts: $ATTACH_ARTIFACTS"
        ;;
      -m|--releaseDesc)
        DESCRIPTION=$VAL
        ;;
      -ev|--executableVersion)
        EXECUTABLE_VERSION=$VAL
        __log "	- Github-release executable version: $EXECUTABLE_VERSION"
        ;;
      -ep|--executablePath)
        EXECUTABLE_PATH=$VAL
        __log "	- Github-release executable location path: $EXECUTABLE_PATH"
        ;;
      -br|--branch)
        TARGET=$VAL
        __log "	- Github-release target branch: $TARGET"
        ;;
      -h|--help)
        __log_and_exit "${_usage_}" 1
        ;;
      *)
        __log_and_exit " --- ERROR: unrecognized FLAG variable in Flag/Value pair: < $FLAG, $VAL > --- " 1
        ;;
    esac
done

if [[ -n "$BUILD_TOOL" ]] && [[ -n "$RELEASE_VERSION" ]]; then
  __log_and_exit " --- ERROR: BUILD_TOOL ($BUILD_TOOL) (-b|--buildTool) and RELEASE_VERSION ($RELEASE_VERSION) (-v|--releaseVersion) cannot both be specified --- " 1
elif [[ -z "$BUILD_TOOL" ]] && [[ -z "$RELEASE_VERSION" ]] || [[ -z "$OWNER" ]]; then
  __log_and_exit " --- ERROR: BUILD_TOOL ($BUILD_TOOL) (-b|--buildTool) or RELEASE_VERSION ($RELEASE_VERSION) (-v|--releaseVersion) and OWNER ($OWNER) (-o|--owner) must be specified --- " 1
elif [[ "$BUILD_TOOL" == "nuget" ]] && [[ -z "$NUGET_PROJECT" ]]; then
  __log_and_exit " -- ERROR: With nuget project, you MUST specify a project name." 1
elif [[ -n "$ARTIFACT_DIRECTORY" ]] && [[ -n "$ARTIFACT_FILE" ]]; then
  __log_and_exit " --- ERROR: ARTIFACT_DIRECTORY ($ARTIFACT_DIRECTORY) (-d|--artifactDirectory) and ARTIFACT_FILE ($ARTIFACT_FILE) (-f|--artifactFile) cannot both be specified --- " 1
elif [[ -z "${GITHUB_TOKEN}" ]]; then
  __log_and_exit " --- ERROR: Environment variable named GITHUB_TOKEN is required to be set in run environment --- " 1
fi

shopt -s nocasematch
if [[ -z "$RELEASE_VERSION" ]]; then
    if [[ "$BUILD_TOOL" == "maven" ]]; then
        RELEASE_VERSION=$(mvn help:evaluate -Dexpression=project.version | grep 'Building')
        RELEASE_VERSION=$(echo $RELEASE_VERSION | awk '{print$NF}')
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
        __log_and_exit " --- ERROR: build tool must either be maven, gradle, or nuget. (you entered: $BUILD_TOOL) --- " 1
    fi
fi
shopt -u nocasematch

if [[ "$RELEASE_VERSION" =~ [0-9]+[.][0-9]+[.][0-9]+ ]] && [[ "$RELEASE_VERSION" != *"SNAPSHOT"* ]]; then #regex matches x.y.z where x,y,z are integers

	####################################	FINDING GITHUB-RELEASE EXECUTABLE FILE 		#####################################
	mkdir -p "${EXECUTABLE_PATH}"

	EXECUTABLE_PATH_EXISTS=$(find ${EXECUTABLE_PATH} -name "github-release")
	if [ -z "${EXECUTABLE_PATH_EXISTS}" ]; then
		__log " --- github-release executable does not already exist --- "
		OS_TYPE=$(uname -s)
		OS_TYPE=${OS_TYPE,,} #convert OS_TYPE to lower case
		if [[ "${OS_TYPE}" =~ ^(darwin|linux)$ ]]; then
			__log " --- Getting necessary github-release executable from github.com/aktau/github-release --- "
			artifactFile="${OS_TYPE}-amd64-github-release.bz2"
			wget -O "${EXECUTABLE_PATH}/${artifactFile}" "https://github.com/aktau/github-release/releases/download/${EXECUTABLE_VERSION}/${artifactFile}"
			bzcat "${EXECUTABLE_PATH}/${artifactFile}" > "${EXECUTABLE_PATH}/github-release"
			chmod +x "${EXECUTABLE_PATH}/github-release"
			__log " --- github-release executable now located in ${EXECUTABLE_PATH} --- "
		elif [[ "${OS_TYPE}" == "mingw" ]]; then
			curl -OL "https://github.com/aktau/github-release/releases/download/${EXECUTABLE_VERSION}/windows-amd64-github-release.zip"
			unzip windows-amd64-github-release.zip
			mv bin/windows/amd64/github-release $EXECUTABLE_PATH
			rm -R bin windows-amd64-github-release.zip
			__log " --- github-release executable now located in ${EXECUTABLE_PATH} --- "
		fi
	fi

	####################################	USING INPUT AND EXECUTABLE FILE TO RELEASE/POST TO GITHUB 		#####################################
	REPO_NAME=$(git remote get-url origin | xargs basename -s .git)

_details_="Build Tool: $BUILD_TOOL
Release Description specified: $DESCRIPTION
Owner: $OWNER
Repository Name: $REPO_NAME
Release Version: $RELEASE_VERSION
Executable Path: $EXECUTABLE_PATH
Branch: $TARGET"

  __log "${_details_}"

	RELEASE_COMMAND_OUTPUT=$(exec "$EXECUTABLE_PATH"/github-release release --user "$OWNER" --repo "$REPO_NAME" --tag "$RELEASE_VERSION" --name "$RELEASE_VERSION" --description "$DESCRIPTION" --target "$TARGET" 2>&1)
	if [[ -z "${RELEASE_COMMAND_OUTPUT}" ]]; then
		__log " --- Release posted to GitHub --- "

		if [[ "$ATTACH_ARTIFACTS" != "true" ]]; then
			__log_and_exit " --- Override set to NOT attach binaries. Script ending. --- " 0
		fi

		if [[ -n "$ARTIFACT_DIRECTORY" ]] && [[ -n "$ARTIFACT_TYPE" ]]; then #looking for file pattern in given directory
			FILE_REGEX=$(echo $ARTIFACT_TYPE | sed 's/\.[^.]*$//') #truncates everything after the ".FileExtension"
			if [[ -z $FILE_REGEX ]]; then
				ARTIFACT_FILE=$(find "$ARTIFACT_DIRECTORY" -iname "$REPO_NAME-$RELEASE_VERSION$ARTIFACT_TYPE")
			else
				ARTIFACT_FILE=$(find "$ARTIFACT_DIRECTORY" -iname "$ARTIFACT_TYPE")
			fi
		elif [[ -z "${ARTIFACT_FILE}" ]]; then #default case - look for .zip or .tar of repo_name-release_version
			ARTIFACT_FILE=$(find . \( -iname "$REPO_NAME-$RELEASE_VERSION.zip" -o -iname "$REPO_NAME-$RELEASE_VERSION.tar" \) -print -quit)
			if [[ -z "$ARTIFACT_FILE" ]]; then
				__log " --- No artifact files found. No artifact will be attached to release. --- "
				__log_and_exit " --- Ending GitHub Autorelease Script --- " 0
			fi
		fi

    foundFileCount=$(echo ${ARTIFACT_FILE} | wc -w)
		if [[ "${foundFileCount}" -ne 1 ]]; then
		  __log " --- ERROR: Expected one file but found ${foundFileCount} --- "
			__log_and_exit "${ARTIFACT_FILE}" 1
		elif [[ ! -f "${ARTIFACT_FILE}" ]]; then
			__log " --- ERROR: Input file does not exist: --- "
			__log_and_exit "${ARTIFACT_FILE}" 1
		else
			ARTIFACT_NAME=$(basename "$ARTIFACT_FILE")
			__log "Artifact File: $ARTIFACT_FILE"
			__log "Artifact Name: $ARTIFACT_NAME"
			POST_COMMAND_OUTPUT=$(exec "$EXECUTABLE_PATH"/github-release upload --user "$OWNER" --repo "$REPO_NAME" --tag "$RELEASE_VERSION" --name "$ARTIFACT_NAME" --file "$ARTIFACT_FILE" 2>&1)

			if [[ -z "$POST_COMMAND_OUTPUT" ]]; then
				__log " --- Artifacts attached to release on GitHub --- "
				__log_and_exit " --- Ending GitHub Autorelease Script --- " 0
			else
				__log_and_exit " --- $POST_COMMAND_OUTPUT --- " 1
			fi
		fi

	else
		__log_and_exit " --- ${RELEASE_COMMAND_OUTPUT} --- " 1
	fi

else
	__log " --- SNAPSHOT found in version name OR version name doesn't follow convention x.y.z where x,y,z are integers separated by .'s - ($RELEASE_VERSION) - NOT releasing to GitHub --- " 0
fi