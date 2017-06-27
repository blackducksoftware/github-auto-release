# Git Hub Auto Release

A release script for automatic release to GitHub

# Build

How to: to run, ./github_auto_release.sh <parameters>     
Parameters:
	-b|--buildTool - required: specify build tool (maven or gradle for now)
	-o|--owner - required: the name of the owner under which the repo is located (default is blackducksoftware)
	-f|--artifactFile - optional: specify file path to project's artifact file (if build artifact is not standard, user can specify to make sure it is released) <CANNOT SPECIFY BOTH A DIRECTORY AND FILE>
	-t|--artifactType - conditionally optional <if specified, artifactDirectory must also be specified>: if file artifact file type is not .zip, .tar, or .jar, specify a file type here and the script will look for a file in workspace that follows the convention of REPO_NAME-RELEASE_VERSION with specified ending
		*you may define as .jar to look for file with name repo_name-release_version.jar, or define regex.jar to find a jar file that matches given regex (ex. *.jar matches any jar with any name)
	-d|--artifactDirectory - conditionally optional <if specified, artifactType must also be specified>: specify a directory to be zipped and released <CANNOT SPECIFY BOTH A DIRECTORY AND FILE>
		*note that if there are more multiple directories with subdirectories of the same name, then you must specify assembly/target, or similar
		*define file paths as follows sub1/sub2/sub3 ...
	-p|--project - conditionally required: IF using a NuGet project, you must provide a project name
	-n|--attachArtifacts - optional: choice to override attaching binaries. If set to false, script will only tag non-SNAPSHOT versions.
	-m|--releaseDesc - optional: add description for release to github
	-ev|--executableVersion - optional: which version of the GitHub-Release executable to be used (default is v0.7.2 because that is the version this script is being tested with)
	-ep|--executablePath - optional: where on the user's machine the GitHub-Release executable will live (defualt is set to ~/temp/blackducksoftware)
	-h|--help - help menu