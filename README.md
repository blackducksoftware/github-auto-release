# Git Hub Auto Release

A release script for automatic release to GitHub that can be executed as a build step in Jenkins or other CI tools.

This script will derive project name and versions for maven, gradle, and nuget projects, and determine whether or not to tag and attach binaries to GitHub. 

The only required inputs are the build tool that the project is using, and the owner of the GitHub repository (you can fork the project and hardcode this if you'd like to).

This script [utilizes this go-based release tool](https://github.com/aktau/github-release). The script will wget the executable to a the folder ~/temp/GARTool. After deriving all relevant
information, the script will use the executable to post to github, and to attach the build artifacts to that release.