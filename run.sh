# ************************************************************
#
# IOS build plugin enable to compile and package ipa from xcode project
#  - Build by simulator if NOT upload p12 and provision profile into flow.ci
#  - Build by iphonesdk if flow.ci has p12 and provision profile
#
#   Variables used:
#     $FLOW_IOS_COMPILE_WORKSPACE
#     $FLOW_IOS_COMPILE_PROJECT
#     $FLOW_PROJECT_GIT_URL
#     $FLOW_IOS_COMPILE_SCHEME
#     $FLOW_IOS_COMPILE_CONFIGURATION
#     $FLOW_IOS_EXPORT_METHOD
#
#   Outputs:
#     $FLOW_IOS_IPA_NAME  the ipa file name, ex: my_app.ipa
#     $FLOW_IOS_IPA_PATH  the full path of ios ipa file, ex: /xx/xx/my_app.ipa
#
# ************************************************************

cd $FLOW_CURRENT_PROJECT_PATH
echo "Begin to install xcodeproj and rebuild shared folder"
gem install xcodeproj && (curl -s https://raw.githubusercontent.com/flow-ci-plugin/flow-recreate-ios-project/master/run.rb > run.rb) && ruby run.rb $FLOW_IOS_PROJECT_PATH_NAME
echo "installed xcodeproj and modified project config correctly"
check_shared_scheme() {
  # check shared scheme
  echo $xcodeproj_shared_scheme_path
  if [[ -d $xcodeproj_shared_scheme_path ]]; then
    num_of_shared_scheme=`ls $xcodeproj_shared_scheme_path | grep -c ".xcscheme"`
    if [ $num_of_shared_scheme -eq 0 ]; then
      echo ' === No shared scheme'
      echo ' === Please share your scheme in Xcode: Product > Scheme > Manage Schemes > Check Shared'
      exit 1
    fi
  else
    echo ' === No shared scheme'
    echo ' === Please share your scheme in Xcode: Product > Scheme > Manage Schemes > Check Shared'
    exit 1
  fi
}

set_project_and_workspace() {
  # Check workspace definition
  if [ -n "$FLOW_IOS_COMPILE_WORKSPACE" ]; then
    params="$params -workspace '$FLOW_IOS_COMPILE_WORKSPACE'"
    fastlane_params="--workspace $FLOW_IOS_COMPILE_WORKSPACE"
  fi

  # Check project definition
  if [ -n "$FLOW_IOS_COMPILE_PROJECT" ]; then
    params="$params -project '$FLOW_IOS_COMPILE_PROJECT'"
    fastlane_params="--project $FLOW_IOS_COMPILE_PROJECT"
  fi

  # Set default project while workspace or project not defined
  if [ -z "$FLOW_IOS_COMPILE_WORKSPACE" ] && [ -z "$FLOW_IOS_COMPILE_PROJECT" ]; then

    if [ -n "$xcworkspace" ]; then
      export FLOW_IOS_COMPILE_WORKSPACE=${xcworkspace:3}
      params="$params -workspace '$FLOW_IOS_COMPILE_WORKSPACE'"
      fastlane_params="--workspace $FLOW_IOS_COMPILE_WORKSPACE"
      echo " === flow.ci will use workspace'$FLOW_IOS_COMPILE_WORKSPACE' as build argument ==="

    else
      export FLOW_IOS_COMPILE_PROJECT=${xcodeproj:3}
      params="$params -project '$FLOW_IOS_COMPILE_PROJECT'"
      fastlane_params="--project $FLOW_IOS_COMPILE_PROJECT"
      echo " === flow.ci will use project '$FLOW_IOS_COMPILE_PROJECT' as build argument ==="
    fi
  fi
  
}

set_scheme() {
  # Set scheme definition
  if [ -n "$FLOW_IOS_COMPILE_SCHEME" ]; then
    params="$params -scheme '$FLOW_IOS_COMPILE_SCHEME'"
  else
    echo $xcodeproj_shared_scheme_path

    scheme_array=($(ls -l $xcodeproj_shared_scheme_path | grep ".xcscheme" | awk '{ print $(NF-0) }'))
    scheme_size=${#scheme_array[@]}

    scheme_name=${scheme_array[$scheme_size - 1]}
    scheme_name=${scheme_name/.xcscheme/}
    params="$params -scheme '${scheme_name}'"

    if [ $scheme_size -gt 1 ]; then
      echo ' === Multiple shared schemes were founded === '
      echo " === ${scheme_array[@]} === "
      echo " === flow.ci will use the scheme: '${scheme_name}' as default === "
    fi
    export FLOW_IOS_COMPILE_SCHEME=$scheme_name
  fi

  fastlane_params="$fastlane_params --scheme $FLOW_IOS_COMPILE_SCHEME"
}

set_destination() {
  # Set build sdk 
  params="$params -sdk iphonesimulator"
}

set_configuration() {
  # Set configuration definition
  if [ -n "$FLOW_IOS_COMPILE_CONFIGURATION" ]; then
    fastlane_params="$fastlane_params --configuration $FLOW_IOS_COMPILE_CONFIGURATION"
    params="$params -configuration '$FLOW_IOS_COMPILE_CONFIGURATION'"
  else
    params="$params -configuration 'Release'"
    export FLOW_IOS_COMPILE_CONFIGURATION="Release"
  fi
}

set_code_identity () {
  # Set code identity definition
  params="$params CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' CODE_SIGNING_ALLOWED=NO"
}

set_export_method () {
  # for Valid values are: app-store, ad-hoc, package, enterprise, development, developer-id 
  if [ -n "$FLOW_IOS_EXPORT_METHOD" ] ; then
    fastlane_params="$fastlane_params --export_method $FLOW_IOS_EXPORT_METHOD" 
  fi
}

# find xcodeproj
xcodeproj=($(find ./ -maxdepth 1 -name "*.xcodeproj"))
xcodeproj_shared_scheme_path=$xcodeproj/xcshareddata/xcschemes

# find workspace
xcworkspace=($(find ./ -maxdepth 1 -name "*.xcworkspace"))

if [ ! $xcodeproj ]; then
 echo ".xcodeproj not found"
 exit 1
else
  check_shared_scheme
fi


# 暂时不支持 -target
# if [ -n "$FLOW_IOS_COMPILE_TARGET" ]; then
#     params="$params -target $FLOW_IOS_COMPILE_TARGET"
#     build_out_dir=$FLOW_IOS_COMPILE_TARGET
# fi

set_project_and_workspace
set_scheme
set_destination
set_configuration
set_code_identity
set_export_method

export FLOW_OUTPUT_DIR=${FLOW_CURRENT_PROJECT_PATH}/flow_output
export FLOW_IOS_FASTLANE_PARAMS=$fastlane_params

if [ -n "$FLOW_IOS_CODE_SIGN_IDENTITY" ]; then
  export FASTLANE_OPT_OUT_USAGE=1
  export FLOW_IOS_IPA_NAME=${FLOW_IOS_COMPILE_CONFIGURATION}-${FLOW_PROJECT_ID}-${FLOW_EVENT_NUMBER}.ipa
  export FLOW_IOS_IPA_PATH=${FLOW_OUTPUT_DIR}/${IPA_NAME}

  fastlane gym $fastlane_params --output_directory ${FLOW_OUTPUT_DIR} --output_name ${FLOW_IOS_IPA_NAME} --silent
else
  cmd="xcodebuild $params SYMROOT=${FLOW_OUTPUT_DIR} | tee ${FLOW_OUTPUT_DIR}/xcodebuild.log | xcpretty -s"
  echo $cmd
  eval $cmd
  
  # fix xcodebuild 失败 但 $? 为 0
  grep -o "BUILD SUCCEEDED" ${FLOW_OUTPUT_DIR}/xcodebuild.log &> /dev/null
fi
