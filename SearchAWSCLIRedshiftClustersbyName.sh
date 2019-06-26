#!/bin/bash

while getopts "p:d:o:m:l:h" arg; do
    case $arg in
        p)
          profileName=${OPTARG}
          ;;
        d)
          databaseForQuery=${OPTARG}
          ;;
        o)
          outputType=${OPTARG}
          ;;
        m)
          matchCount=${OPTARG}
          ;;
        l)
          lineCount=${OPTARG}
          ;;
        h)
          cat <<- EOF
          [HELP]: ### SearchAWSCLIRedshiftClustersbyName. Go find database clusters in my aws profile across all configured regions matching string. ###
		   
          [EXAMPLE]: scriptname -d myrs-cluster -p my-amazon-profile -o table -m 2 -l 25"
          
          [REQUIREMENTS]: This script requires only two arguments -d and -p, and requires the user to have setup aws profiles setup in
		  order to use this tool.
		  
         [REQUIRED ARGUMENTS]:
            -d) [database cluster] [STRING] This option refers to the database cluster name to search for. The search will match any correctly spelled approxmation.
            -p) [profile] [STRING] This option refers to the profile to be used for AWS. This should exist in $HOME/.aws/credentials.
		  
         [OPTIONAL ARGUMENTS]:
            -o) [Output Type] [STRING]This option sets the output type. Defaults to JSON, accepts text | table | json.
            -m) [Matches] [INTEGER] This option sets the amount of matches to return.
            -l) [Output Lines] [INTEGER] This option sets the amount of output lines per match to return.
            -h) [HELP] [takes no arguements] Print this dialog to the screen.
EOF
         exit 0
         ;;
      *)
         printf "%s\n" "Incorrect syntax, try -h for help"
         exit 0
         ;;
    esac
done

trap ctrl_c INT

function ctrl_c() {
        echo "** Caught SIGINT: CTRL-C **"
        exit 1
}

awsCliLocale=$(command -v aws)
credsFile=$HOME/.aws/credentials
# User Variables (ALLCAPS)
AWSREGIONS="us-east-2 us-east-1 us-west-1 us-west-2 ap-south-1 ap-northeast-2 \
ap-southeast-1 ap-southeast-2 ap-northeast-1 ca-central-1 eu-central-1 \
eu-west-1 eu-west-2 eu-west-3 eu-north-1 sa-east-1"
DEFAULT_MATCH_OUTPUT_LINES=162
function CheckRequirements() {
        if [ -z "$databaseForQuery" ] || [ -z "$profileName"  ] || [ -z "$awsCliLocale" ] ; then
        
                if [ -z "$databaseForQuery" ] ; then
                        printf "%s\n" "[ERROR]: Missing arguments, requires database cluster name (-d), profile(from aws credentials file) (-p)." \
                               "You may also recieve this message if the script cannot locate your awscli install."
                        exit 1
                elif [ -z "$profileName" ]; then
                        printf "%s\n" "[ERROR]: Missing arguement for -p (profile), this script requires two arguments, and an awscli credentials file."
                        exit 1
                elif [ -z "$awsCliLocale" ]; then
                        printf "%s\n" "[ERROR]: Unable to find awscli executable, is it installed, or on your '$PATH'?"
                        exit 1
                fi

        elif [ -r "$credsFile" ]; then
        	profileDefined=$(sed -e s'/\[//g;s/\]//g' "$credsFile" | grep -c -m $matchCount "$profileName")
        	if [ -z "$profileDefined" ] || [ "$profileDefined" -ne 1 ]; then
        		printf "%s\n" "Couldn't find a matching profile in $credsFile."
        		exit 1
        	else
                	environmentSane=0
                	if [ $matchCount -le 1 ] ; then
                	        matchCount=1
                	fi
                	if [ -z $lineCount ]; then
                        	lineCount=$DEFAULT_MATCH_OUTPUT_LINES
                	fi
                    if [[ $outputType == "text" ]]; then
                            printf "%\s" "Cannot output in text, exiting."
                            exit 1
                    else
                            export SEARCHTERM="ClusterIdentifier"
                    fi
                fi
        else
                printf "%s\n" "[ERROR]: User has not setup AWS credentials file. For \
                more information, visit: \
                https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html"
                exit 1
        fi
}

function CheckDatabase() {
        Green='\033[0;32m'
        Red='\033[0;31m'
        NoColor='\033[0m'
        if [ -z "$outputType" ]; then
                outputType="json"
        fi
        for i in $AWSREGIONS
            do 
                echo -e "${Green}[INFO]: ##################### AWS PROFILE: ${NoColor}${Red}${profileName}${NoColor}${Green}\
                REGION: ${NoColor}${Red}${i}${NoColor}${Green}###################${NoColor}"
                if ! aws redshift describe-clusters --profile "$profileName" --region "$i" --output $outputType 2> /dev/null \
                    | grep --color -m "$matchCount" -A "$lineCount" -i  -E ${SEARCHTERM}.*"${databaseForQuery}" 2> /dev/null ; then
                    printf "%s\n" "[INFO]: Database Cluster not found in $i region."
                else
                    echo  -e "\033[33;5;7m[SUCCESS]: DATABASE CLUSTER OR DATABASE CLUSTER(S) FOUND\033[0m"
                    exit 0
                fi
            done
}
CheckRequirements
if [ "$environmentSane" -eq 0 ]; then
        CheckDatabase
fi
