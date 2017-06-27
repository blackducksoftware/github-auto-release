# Git Hub Auto Release

A release script for automatic release to GitHub that can be executed as a build step in Jenkins or other CI tools.

This script will derive project name and versions for maven, gradle, and nuget projects, and determine whether or not to tag and attach binaries to GitHub. 

The only required input's are the build tool that the project is using, and the owner of the GitHub repository (you can fork the project and hardcode this if you'd like to).


# Available Parameters and Overrides
* Required:
  * -b|--buildTool 
    * specify build tool (maven or gradle for now)
  * -o|--owner
    * name of the owner under which the repo is located

* Optional
  * -f|--artifactFile
    * specify file path to project's artifact file (if build artifact is not standard, user can specify to make sure it is released) **CANNOT SPECIFY BOTH A DIRECTORY AND FILE**
  * -n|--attachArtifacts 
    * choice to override attaching binaries. If set to false, script will only tag non-SNAPSHOT versions.
  * -m|--releaseDesc
    * add description for release to github
  * -h|--help 
    * help menu

* Conitionally Optional
  * -p|--project
    * _IF_ using a NuGet project, you must provide a project name
  * -t|--artifactType 
    * **if specified, artifactDirectory must also be specified** - if file artifact file type is not .zip or .tar specify a file type here and the script will look for a file in workspace that follows the convention of REPO_NAME-RELEASE_VERSION with specified ending. You may define as .jar to look for file with name repo_name-release_version.jar, or define _regex_.jar to find a jar file that matches given _regex_ (ex. *.jar matches any .jar file)
  * -d|--artifactDirectory
    * **if specified, artifactType must also be specified** - specify a directory to be zipped and released **CANNOT SPECIFY BOTH A DIRECTORY AND FILE**
    * note that if there are more multiple directories with subdirectories of the same name, then you must specify assembly/target, or similar
    * define file paths as follows sub1/sub2/sub3 ...

* Overrides
  * -ev|--executableVersion
    * which version of the GitHub-Release executable to be used (default is v0.7.2 because that is the version this script is being tested with)
  * -ep|--executablePath 
    * where on the user's machine the GitHub-Release executable will live (defualt is set to ~/temp/GARTool)




