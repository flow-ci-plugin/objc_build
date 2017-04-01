cd $FLOW_CURRENT_PROJECT_PATH

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
  fi

  # Check project definition
  if [ -n "$FLOW_IOS_COMPILE_PROJECT" ]; then
    params="$params -project '$FLOW_IOS_COMPILE_PROJECT'"
    echo " ===1 $FLOW_IOS_COMPILE_PROJECT"
  fi

  # Set default project while workspace or project not defined
  if [ -z "$FLOW_IOS_COMPILE_WORKSPACE"] && [ -z "$FLOW_IOS_COMPILE_PROJECT" ]; then

    if [ -n "$xcworkspace" ]; then
      export FLOW_IOS_COMPILE_WORKSPACE=${xcworkspace:3}
      params="$params -workspace '$FLOW_IOS_COMPILE_WORKSPACE'"
      echo " === flow.ci will use workspace'$FLOW_IOS_COMPILE_WORKSPACE' as build argument ==="

    else
      export FLOW_IOS_COMPILE_PROJECT=${xcodeproj:3}
      params="$params -project '$FLOW_IOS_COMPILE_PROJECT'"
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
}

set_destination() {
  # Set build destination
  if [ -n "$FLOW_IOS_CODE_SIGN_IDENTITY" ]; then
    params="$params -sdk $FLOW_IOS_COMPILE_SDK" 
  else 
    params="$params -destination 'platform=iOS Simulator,name=iPhone 6'"
  fi
}

set_configuration() {
  # Set configuration definition
  if [ -n "$FLOW_IOS_COMPILE_CONFIGURATION" ]; then
    params="$params -configuration '$FLOW_IOS_COMPILE_CONFIGURATION'"
  else
    params="$params -configuration 'Release'"
    export FLOW_IOS_COMPILE_CONFIGURATION="Release"
  fi
}

set_code_identity () {
  # Set code identity definition
    params="$params CODE_SIGN_IDENTITY='iPhone Distribution'"
}

export FLOW_IOS_COMPILE_SDK="iphoneos"

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

  # Find DevelopmentTeam in xcodeproj
  TEAM_ARR=($(awk -F '=' '/DevelopmentTeam/ {print $2}' "$xcodeproj"/project.pbxproj))
  # Replace DevelopmentTeam value to none
  for s in ${TEAM_ARR[@]}
  do
    cmd="/DevelopmentTeam  = ${s}/DevelopmentTeam = \"\";/g"
    sed -i '' s"$cmd" "$xcodeproj"/project.pbxproj
  done

  # Find PROVISIONING_PROFILE in xcodeproj
  PROVISIONING_PROFILE_ARR=($(awk -F '=' '/PROVISIONING_PROFILE/ {print $2}' "$xcodeproj"/project.pbxproj))
  # Replace PROVISIONING_PROFILE value to none
  for s in ${PROVISIONING_PROFILE_ARR[@]}
  do
   cmd="/PROVISIONING_PROFILE = ${s}/PROVISIONING_PROFILE = \"\";/g"
   sed -i '' s"$cmd" "$xcodeproj"/project.pbxproj
  done

  # Find DEVELOPMENT_TEAM in xcodeproj
  DEVELOPMENT_TEAM_ARR=($(awk -F '=' '/DEVELOPMENT_TEAM/ {print $2}' "$xcodeproj"/project.pbxproj))
  # Replace DEVELOPMENT_TEAM value to none
  for s in ${DEVELOPMENT_TEAM_ARR[@]}
  do
   cmd="/DEVELOPMENT_TEAM = ${s}/DEVELOPMENT_TEAM = \"\";/g"
   sed -i '' s"$cmd" "$xcodeproj"/project.pbxproj
  done

  # Replace ProvisioningStyle 'Automatic' to 'Manual'
  sed -i '' s'/ProvisioningStyle = Automatic/ProvisioningStyle = Manual/g' "$xcodeproj"/project.pbxproj

  # Replace PROVISIONING_PROFILE_SPECIFIER to none
  sed -i -e "/PROVISIONING_PROFILE_SPECIFIER/d" "$xcodeproj"/project.pbxproj
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

export FLOW_OUTPUT_DIR=${FLOW_WORKSPACE}/output
cmd="xcodebuild $params SYMROOT=${FLOW_OUTPUT_DIR} | tee ${FLOW_OUTPUT_DIR}/xcodebuild.log | xcpretty -s"
echo $cmd
eval $cmd

# fix xcodebuild 失败 但 $? 为 0
grep -o "BUILD SUCCEEDED" ${FLOW_OUTPUT_DIR}/xcodebuild.log &> /dev/null

# report html
# cat ${FLOW_OUTPUT_DIR}/xcodebuild.log | xcpretty -r  html --output ${FLOW_OUTPUT_DIR}/xcodebuild.html
